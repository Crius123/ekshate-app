import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  calculateParcelWeight,
  PathaoCourierAdapter,
  SteadfastCourierAdapter,
  RedXCourierAdapter,
  CourierGateway,
  executeCampaignDispatch,
  NormalizedBookingPayload,
} from '../courierDispatch';

class MockFirestore {
  public docs: Map<string, any> = new Map();
  private autoIdCounter = 2000;

  generateId(prefix = 'doc_'): string {
    this.autoIdCounter++;
    return `${prefix}${this.autoIdCounter}`;
  }

  setDoc(path: string, data: any) {
    this.docs.set(path, { ...data });
  }

  getDoc(path: string) {
    const d = this.docs.get(path);
    return d ? { ...d } : undefined;
  }

  getAllDocsInCollection(collectionPrefix: string) {
    const results: Array<{ path: string; id: string; data: any }> = [];
    for (const [path, data] of this.docs.entries()) {
      if (path.startsWith(collectionPrefix + '/')) {
        const subPath = path.substring(collectionPrefix.length + 1);
        if (!subPath.includes('/')) {
          results.push({ path, id: subPath, data: { ...data } });
        }
      }
    }
    return results;
  }

  collection(collectionPath: string) {
    return this.createCollectionRef(collectionPath);
  }

  private createCollectionRef(path: string): any {
    return {
      path,
      doc: (docId?: string) => {
        const id = docId || this.generateId('gen_');
        const docPath = `${path}/${id}`;
        return this.createDocRef(docPath, id);
      },
      get: async () => {
        const allDocs = this.getAllDocsInCollection(path);
        return {
          empty: allDocs.length === 0,
          size: allDocs.length,
          docs: allDocs.map((f) => ({
            id: f.id,
            ref: this.createDocRef(f.path, f.id),
            data: () => ({ ...f.data }),
          })),
        };
      },
      where: (field: string, op: string, value: any) => {
        const queryFilters: Array<{ field: string; op: string; value: any }> = [
          { field, op, value },
        ];
        const queryObj = {
          where: (f2: string, op2: string, v2: any) => {
            queryFilters.push({ field: f2, op: op2, value: v2 });
            return queryObj;
          },
          get: async () => {
            const allDocs = this.getAllDocsInCollection(path);
            const filtered = allDocs.filter((d) => {
              return queryFilters.every((q) => {
                const val = d.data[q.field];
                if (q.op === '==') return val === q.value;
                if (q.op === 'in') return Array.isArray(q.value) && q.value.includes(val);
                return false;
              });
            });

            return {
              empty: filtered.length === 0,
              size: filtered.length,
              docs: filtered.map((f) => ({
                id: f.id,
                ref: this.createDocRef(f.path, f.id),
                data: () => ({ ...f.data }),
              })),
            };
          },
        };
        return queryObj;
      },
    };
  }

  private createDocRef(docPath: string, docId: string): any {
    return {
      path: docPath,
      id: docId,
      get: async () => {
        const data = this.docs.get(docPath);
        return {
          exists: data !== undefined,
          id: docId,
          ref: this.createDocRef(docPath, docId),
          data: () => (data ? { ...data } : undefined),
        };
      },
      set: async (data: any, options?: { merge?: boolean }) => {
        if (options?.merge) {
          const current = this.docs.get(docPath) || {};
          this.docs.set(docPath, { ...current, ...data });
        } else {
          this.docs.set(docPath, { ...data });
        }
      },
      update: async (data: any) => {
        const current = this.docs.get(docPath);
        if (!current) {
          throw new Error(`Doc not found: ${docPath}`);
        }
        this.docs.set(docPath, { ...current, ...data });
      },
    };
  }

  batch() {
    const stagedUpdates: Array<() => void> = [];
    return {
      update: (docRef: any, data: any) => {
        stagedUpdates.push(() => {
          const current = this.docs.get(docRef.path) || {};
          this.docs.set(docRef.path, { ...current, ...data });
        });
      },
      set: (docRef: any, data: any, options?: { merge?: boolean }) => {
        stagedUpdates.push(() => {
          if (options?.merge) {
            const current = this.docs.get(docRef.path) || {};
            this.docs.set(docRef.path, { ...current, ...data });
          } else {
            this.docs.set(docRef.path, { ...data });
          }
        });
      },
      commit: async () => {
        for (const u of stagedUpdates) {
          u();
        }
      },
    };
  }
}

describe('Local Courier Dispatch API Integration & Parcel Generation Tests', () => {
  const samplePayload: NormalizedBookingPayload = {
    orderId: 'ord_1001',
    recipientName: 'Sheikh Buyer',
    recipientPhone: '+8801711000001',
    recipientAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    recipientCity: 'Dhaka',
    packageWeightKg: 10.0,
    itemDescription: 'Nagpur Oranges (1 kg) (10 kg)',
    itemQuantity: 10,
    totalOrderAmount: 1800,
    amountToCollect: 0,
    specialInstructions: 'Handle with care - Fresh Fruits',
  };

  it('calculates parcel packaging weight accurately across distinct produce types and enforces min clamp', () => {
    // 1. Direct kg
    assert.equal(calculateParcelWeight(10, 'kg', 'fruit', 'Nagpur Oranges (1 kg)'), 10.0);
    assert.equal(calculateParcelWeight(2.5, 'kg', 'vegetable', 'Fresh Red Tomatoes'), 2.5);

    // 2. Direct grams
    assert.equal(calculateParcelWeight(500, 'g', 'spice', 'Chilli Powder'), 0.5);
    // 50g -> 0.05kg -> minimum clamp to 0.5 kg
    assert.equal(calculateParcelWeight(50, 'g', 'spice', 'Saffron'), 0.5);

    // 3. Liter produce / oil
    assert.equal(calculateParcelWeight(3, 'liter', 'oil', 'Mustard Oil'), 3.0);

    // 4. Bags / sacks parsed from title
    // "Miniket Premium Rice (25 kg bag)" x 2 = 50 kg
    assert.equal(
      calculateParcelWeight(2, 'bag', 'grain', 'Miniket Premium Rice (25 kg bag)'),
      50.0
    );
    // "Potato (50 kg sack)" x 1 = 50 kg
    assert.equal(calculateParcelWeight(1, 'sack', 'produce', 'Potato (50 kg sack)'), 50.0);

    // 5. Jars / tins parsed from title
    // "Pure Mustard Oil (5 L jar)" x 2 = 10 kg
    assert.equal(
      calculateParcelWeight(2, 'jar', 'oil', 'Pure Mustard Oil (5 L jar)'),
      10.0
    );

    // 6. Crates parsed from title
    // "Alphonso Mango (10 kg crate)" x 3 = 30 kg
    assert.equal(
      calculateParcelWeight(3, 'crate', 'fruit', 'Alphonso Mango (10 kg crate)'),
      30.0
    );

    // 7. Embedded packaging packet spec in title
    // "Tata Salt (1 kg packet)" x 4 = 4.0 kg
    assert.equal(calculateParcelWeight(4, 'packet', 'staple', 'Tata Salt (1 kg packet)'), 4.0);
  });

  it('verifies Pathao Courier adapter formatting and mock consignment generation', async () => {
    const adapter = new PathaoCourierAdapter({ storeId: 999 }, true);
    const formatted = adapter.formatPayload(samplePayload);

    assert.equal(formatted.merchant_order_id, 'ord_1001');
    assert.equal(formatted.recipient_name, 'Sheikh Buyer');
    assert.equal(formatted.recipient_phone, '+8801711000001');
    assert.equal(formatted.delivery_type, 48);
    assert.equal(formatted.item_type, 2);
    assert.equal(formatted.amount_to_collect, 0);
    assert.equal(formatted.item_weight, 10.0);

    const result = await adapter.createConsignment(samplePayload);
    assert.equal(result.success, true);
    assert.equal(result.courierPartner, 'pathao');
    assert.equal(result.consignmentId, 'PTH-CON-ord1001');
    assert.equal(result.trackingCode, 'PTH-TRK-ord1001');
    assert.match(result.trackingUrl, /pathao\.com\/courier\/tracking/);
    assert.equal(result.deliveryFee, 60 + 9 * 20); // 240 BDT for 10 kg
  });

  it('verifies Steadfast Courier adapter formatting and mock consignment generation', async () => {
    const adapter = new SteadfastCourierAdapter({}, true);
    const formatted = adapter.formatPayload(samplePayload);

    assert.equal(formatted.invoice, 'ord_1001');
    assert.equal(formatted.recipient_name, 'Sheikh Buyer');
    assert.equal(formatted.recipient_phone, '+8801711000001');
    assert.equal(formatted.cod_amount, 0);
    assert.match(formatted.note, /10 kg/);

    const result = await adapter.createConsignment(samplePayload);
    assert.equal(result.success, true);
    assert.equal(result.courierPartner, 'steadfast');
    assert.equal(result.consignmentId, 'SF-CON-ord1001');
    assert.equal(result.trackingCode, 'SF-TRK-ord1001');
    assert.match(result.trackingUrl, /steadfast\.com\.bd\/t/);
    assert.equal(result.deliveryFee, 70 + 9 * 15); // 205 BDT
  });

  it('verifies RedX Courier adapter formatting and mock consignment generation', async () => {
    const adapter = new RedXCourierAdapter({}, true);
    const formatted = adapter.formatPayload(samplePayload);

    assert.equal(formatted.merchant_invoice_id, 'ord_1001');
    assert.equal(formatted.customer_name, 'Sheikh Buyer');
    assert.equal(formatted.customer_phone, '+8801711000001');
    assert.equal(formatted.parcel_weight, 10000); // 10 kg in grams for RedX!
    assert.equal(formatted.cash_collection_amount, 0);
    assert.equal(formatted.value, 1800);

    const result = await adapter.createConsignment(samplePayload);
    assert.equal(result.success, true);
    assert.equal(result.courierPartner, 'redx');
    assert.equal(result.consignmentId, 'REDX-CON-ord1001');
    assert.equal(result.trackingCode, 'REDX-TRK-ord1001');
    assert.match(result.trackingUrl, /redx\.com\.bd\/track-parcel/);
    assert.equal(result.deliveryFee, 65 + 9 * 18);
  });

  it('executes automated courier fallback when primary partner suffers outage', async () => {
    const gateway = new CourierGateway({ mockMode: true });

    // Primary: Pathao
    const primaryResult = await gateway.bookConsignment(samplePayload, 'pathao');
    assert.equal(primaryResult.success, true);
    assert.equal(primaryResult.courierPartner, 'pathao');

    // Simulate Pathao outage
    gateway.simulateFailure('pathao', true);

    // Fallback: should automatically reserve with Steadfast
    const fallbackResult = await gateway.bookConsignment(samplePayload, 'pathao');
    assert.equal(fallbackResult.success, true);
    assert.equal(fallbackResult.courierPartner, 'steadfast');
    assert.equal(fallbackResult.consignmentId, 'SF-CON-ord1001');

    // Simulate Steadfast outage as well: should fall back to RedX
    gateway.simulateFailure('steadfast', true);
    const redxFallbackResult = await gateway.bookConsignment(samplePayload, 'pathao');
    assert.equal(redxFallbackResult.success, true);
    assert.equal(redxFallbackResult.courierPartner, 'redx');
    assert.equal(redxFallbackResult.consignmentId, 'REDX-CON-ord1001');

    // Simulate all 3 failing: should return failure report
    gateway.simulateFailure('redx', true);
    const totalFailure = await gateway.bookConsignment(samplePayload, 'pathao');
    assert.equal(totalFailure.success, false);
    assert.match(totalFailure.error || '', /All couriers in fallback chain failed/);
  });

  it('processes campaign confirmed orders, computes parcel weights, updates Firestore, and creates batch manifest', async () => {
    const mockDb = new MockFirestore();
    const campaignDate = '2026-10-23';

    // Seed confirmed orders
    mockDb.setDoc('orders/ord_test_01', {
      order_id: 'ord_test_01',
      date: campaignDate,
      status: 'confirmed',
      user_name: 'Tanvir Hossain',
      user_phone: '+8801711000001',
      delivery_address: 'House 5, Road 2, Dhanmondi, Dhaka',
      product_title: 'Nagpur Oranges (1 kg)',
      quantity: 10,
      unit: 'kg',
      category: 'fruit',
      total_amount: 1800,
    });

    mockDb.setDoc('orders/ord_test_02', {
      order_id: 'ord_test_02',
      date: campaignDate,
      status: 'confirmed',
      user_name: 'Anika Rahman',
      user_phone: '+8801811000002',
      delivery_address: 'Flat 4B, Banani DOHS, Dhaka',
      product_title: 'Miniket Premium Rice (25 kg bag)',
      quantity: 1,
      unit: 'bag',
      category: 'grain',
      total_amount: 1750,
    });

    // Seed a pending order that should NOT be dispatched yet
    mockDb.setDoc('orders/ord_test_03', {
      order_id: 'ord_test_03',
      date: campaignDate,
      status: 'pending_bucket',
      product_title: 'Pure Mustard Oil (5 L jar)',
      quantity: 1,
      unit: 'jar',
    });

    const report = await executeCampaignDispatch({
      date: campaignDate,
      db: mockDb,
      preferredCourier: 'pathao',
    });

    assert.equal(report.totalOrders, 2);
    assert.equal(report.dispatchedCount, 2);
    assert.equal(report.failedCount, 0);
    assert.equal(report.totalWeightKg, 35.0); // 10 kg + 25 kg
    assert.equal(report.dispatchedOrders.length, 2);

    // Verify Firestore updates on order 1
    const order1 = mockDb.getDoc('orders/ord_test_01');
    assert.equal(order1.status, 'dispatched');
    assert.equal(order1.courier_partner, 'pathao');
    assert.equal(order1.consignment_id, 'PTH-CON-ordtest01');
    assert.equal(order1.tracking_code, 'PTH-TRK-ordtest01');
    assert.equal(order1.parcel_weight_kg, 10.0);
    assert.ok(order1.dispatched_at);

    // Verify Firestore updates on order 2
    const order2 = mockDb.getDoc('orders/ord_test_02');
    assert.equal(order2.status, 'dispatched');
    assert.equal(order2.courier_partner, 'pathao');
    assert.equal(order2.consignment_id, 'PTH-CON-ordtest02');
    assert.equal(order2.tracking_code, 'PTH-TRK-ordtest02');
    assert.equal(order2.parcel_weight_kg, 25.0);

    // Verify pending order remains untouched
    const order3 = mockDb.getDoc('orders/ord_test_03');
    assert.equal(order3.status, 'pending_bucket');
    assert.equal(order3.consignment_id, undefined);

    // Verify dispatch batch manifest document was recorded
    const batchDoc = mockDb.getDoc(`dispatch_batches/${campaignDate}`);
    assert.ok(batchDoc);
    assert.equal(batchDoc.status, 'completed');
    assert.equal(batchDoc.total_orders, 2);
    assert.equal(batchDoc.dispatched_count, 2);
    assert.equal(batchDoc.total_weight_kg, 35.0);
  });

  it('guarantees idempotency on re-dispatch of already dispatched campaign', async () => {
    const mockDb = new MockFirestore();
    const campaignDate = '2026-10-23';

    // Order already marked as dispatched with tracking
    mockDb.setDoc('orders/ord_already_dispatched', {
      order_id: 'ord_already_dispatched',
      date: campaignDate,
      status: 'dispatched',
      courier_partner: 'pathao',
      consignment_id: 'PTH-CON-already',
      tracking_code: 'PTH-TRK-already',
      quantity: 5,
      unit: 'kg',
      product_title: 'Apples',
    });

    const report = await executeCampaignDispatch({
      date: campaignDate,
      db: mockDb,
    });

    // Zero new dispatches
    assert.equal(report.dispatchedCount, 0);
    assert.equal(report.alreadyDispatchedCount, 0); // Not returned by query status=='confirmed'
  });

  it('handles batch chunking with large numbers of confirmed orders (>50)', async () => {
    const mockDb = new MockFirestore();
    const campaignDate = '2026-10-24';

    // Create 65 confirmed orders
    for (let i = 1; i <= 65; i++) {
      const orderId = `ord_bulk_${i.toString().padStart(3, '0')}`;
      mockDb.setDoc(`orders/${orderId}`, {
        order_id: orderId,
        date: campaignDate,
        status: 'confirmed',
        product_title: 'Nagpur Oranges (1 kg)',
        quantity: 2,
        unit: 'kg',
        total_amount: 360,
      });
    }

    const report = await executeCampaignDispatch({
      date: campaignDate,
      db: mockDb,
      batchChunkSize: 25, // Forces 3 chunks (25 + 25 + 15)
    });

    assert.equal(report.totalOrders, 65);
    assert.equal(report.dispatchedCount, 65);
    assert.equal(report.failedCount, 0);
    assert.equal(report.totalWeightKg, 130.0); // 65 * 2 kg
  });
});
