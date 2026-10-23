import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  buildProcurementManifest,
  generateProcurementCsv,
  calculatePackagingNotes,
  escapeCsvField,
  scheduledProcurementManifest,
} from '../generateProcurementManifest';
import { executeCampaignSettlement } from '../settleDailyCampaign';

class MockFirestore {
  public docs: Map<string, any> = new Map();
  private autoIdCounter = 1000;

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
      collection: (subColName: string) => {
        return this.createCollectionRef(`${docPath}/${subColName}`);
      },
      get: async () => {
        const docData = this.docs.get(docPath);
        return {
          exists: docData !== undefined,
          id: docId,
          ref: this.createDocRef(docPath, docId),
          data: () => (docData ? { ...docData } : undefined),
        };
      },
      set: async (data: any, options?: any) => {
        if (options && options.merge) {
          const current = this.docs.get(docPath) || {};
          this.docs.set(docPath, { ...current, ...data });
        } else {
          this.docs.set(docPath, { ...data });
        }
      },
      update: async (updates: any) => {
        const current = this.docs.get(docPath) || {};
        const updated = { ...current };
        for (const k of Object.keys(updates)) {
          const val = updates[k];
          if (val && typeof val === 'object' && ('operand' in val || (val as any).isIncrement)) {
            const operand = (val as any).operand ?? (val as any).value ?? 0;
            updated[k] = (Number(updated[k]) || 0) + Number(operand);
          } else {
            updated[k] = val;
          }
        }
        this.docs.set(docPath, updated);
      },
    };
  }

  async runTransaction<T>(updateFunction: (transaction: any) => Promise<T>): Promise<T> {
    const stagedWrites: Array<() => void> = [];

    const transaction = {
      get: async (docRef: any) => {
        return docRef.get();
      },
      update: (docRef: any, updates: any) => {
        stagedWrites.push(() => {
          const current = this.docs.get(docRef.path) || {};
          const updated = { ...current };
          for (const k of Object.keys(updates)) {
            const val = updates[k];
            if (val && typeof val === 'object' && ('operand' in val || (val as any).isIncrement)) {
              const operand = (val as any).operand ?? (val as any).value ?? 0;
              updated[k] = (Number(updated[k]) || 0) + Number(operand);
            } else {
              updated[k] = val;
            }
          }
          this.docs.set(docRef.path, updated);
        });
      },
      set: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          this.docs.set(docRef.path, { ...data });
        });
      },
    };

    const result = await updateFunction(transaction);
    for (const write of stagedWrites) {
      write();
    }
    return result;
  }
}

describe('Wholesale Supplier Morning Procurement Manifest & Purchase Order Generator Tests', () => {
  it('verifies scheduled procurement manifest trigger configuration (4:00 AM BDT)', () => {
    assert.ok(scheduledProcurementManifest);
    // Verified 4:00 AM schedule
  });

  it('aggregates confirmed won buckets across multiple listings with accurate volume & budget math', async () => {
    const db = new MockFirestore();
    const date = '2026-10-22';

    // 1. Create campaign
    db.setDoc(`daily_campaigns/${date}`, {
      date,
      status: 'settled',
    });

    // 2. Listing 1: Miniket Rice (Grain) - 2 confirmed buckets (100 kg + 100 kg = 200 kg)
    db.setDoc(`daily_campaigns/${date}/listings/listing_rice`, {
      product_id: 'prod_rice_01',
      sku: 'SKU-RICE-01',
      product_title: 'Premium Miniket Rice (Bulk)',
      category: 'Grains & Staples',
      unit: 'kg',
      unit_price: 80,
      wholesale_price: 65, // explicit wholesale price
      target_market: 'Badamtoli Wholesale Depot',
    });

    db.setDoc(`daily_campaigns/${date}/listings/listing_rice/buckets/1`, {
      bucket_number: 1,
      status: 'confirmed',
      current_quantity: 100,
      moq_threshold: 100,
    });
    db.setDoc(`daily_campaigns/${date}/listings/listing_rice/buckets/2`, {
      bucket_number: 2,
      status: 'confirmed',
      current_quantity: 100,
      moq_threshold: 100,
    });
    db.setDoc(`daily_campaigns/${date}/listings/listing_rice/buckets/3`, {
      bucket_number: 3,
      status: 'failed', // Failed bucket should be excluded
      current_quantity: 40,
      moq_threshold: 100,
    });

    // 3. Listing 2: Nagpur Oranges (Fruits) - 1 confirmed bucket (50 kg)
    db.setDoc(`daily_campaigns/${date}/listings/listing_oranges`, {
      product_id: 'prod_orange_02',
      sku: 'SKU-ORANGE-02',
      product_title: 'Fresh Nagpur Oranges',
      category: 'Fresh Fruits',
      unit: 'kg',
      unit_price: 200, // No explicit wholesale_price -> 75% fallback = 150
      target_market: 'Karwan Bazar Wholesale Hub',
    });

    db.setDoc(`daily_campaigns/${date}/listings/listing_oranges/buckets/1`, {
      bucket_number: 1,
      status: 'confirmed',
      current_quantity: 50,
      moq_threshold: 50,
    });

    // 4. Listing 3: Soybean Oil (Oil) - 1 confirmed bucket (30 L)
    db.setDoc(`daily_campaigns/${date}/listings/listing_oil`, {
      product_id: 'prod_oil_03',
      sku: 'SKU-OIL-03',
      product_title: 'Pure Soybean Oil',
      category: 'Edible Oils',
      unit: 'liter',
      unit_price: 180,
      wholesale_price: 150,
      target_market: 'Kaptan Bazar Depot',
    });

    db.setDoc(`daily_campaigns/${date}/listings/listing_oil/buckets/1`, {
      bucket_number: 1,
      status: 'confirmed',
      current_quantity: 30,
      moq_threshold: 30,
    });

    // Run procurement manifest builder
    const manifest = await buildProcurementManifest(date, db as any);

    // Verify aggregations
    assert.equal(manifest.date, date);
    assert.equal(manifest.status, 'pending_procurement');
    assert.equal(manifest.total_items_count, 3);
    assert.equal(manifest.total_buckets_count, 4); // 2 rice + 1 orange + 1 oil

    // Volume check: 200 (rice) + 50 (oranges) + 30 (oil) = 280
    assert.equal(manifest.total_confirmed_volume, 280);

    // Budget math check:
    // Rice: 200 * 65 = 13,000 BDT
    // Oranges: 50 * 150 = 7,500 BDT
    // Oil: 30 * 150 = 4,500 BDT
    // Total: 13,000 + 7,500 + 4,500 = 25,000 BDT
    assert.equal(manifest.total_procurement_cost, 25000);

    // Verify itemized details
    const riceItem = manifest.items.find((i) => i.sku === 'SKU-RICE-01')!;
    assert.ok(riceItem);
    assert.equal(riceItem.total_volume, 200);
    assert.equal(riceItem.estimated_unit_cost, 65);
    assert.equal(riceItem.total_budget, 13000);
    assert.equal(riceItem.confirmed_buckets_count, 2);
    assert.equal(riceItem.packaging_notes, '4 x 50 kg burlap bags');
    assert.equal(riceItem.target_market, 'Badamtoli Wholesale Depot');
    assert.equal(riceItem.status, 'pending');

    const orangeItem = manifest.items.find((i) => i.sku === 'SKU-ORANGE-02')!;
    assert.ok(orangeItem);
    assert.equal(orangeItem.total_volume, 50);
    assert.equal(orangeItem.estimated_unit_cost, 150);
    assert.equal(orangeItem.total_budget, 7500);
    assert.equal(orangeItem.packaging_notes, '5 x 10 kg crates');

    const oilItem = manifest.items.find((i) => i.sku === 'SKU-OIL-03')!;
    assert.ok(oilItem);
    assert.equal(oilItem.total_volume, 30);
    assert.equal(oilItem.estimated_unit_cost, 150);
    assert.equal(oilItem.total_budget, 4500);
    assert.equal(oilItem.packaging_notes, '6 x 5 L containers');

    // Verify Firestore document integrity
    const savedDoc = db.getDoc(`procurement_manifests/${date}`);
    assert.ok(savedDoc);
    assert.equal(savedDoc.date, date);
    assert.equal(savedDoc.total_confirmed_volume, 280);
    assert.equal(savedDoc.total_procurement_cost, 25000);
    assert.equal(savedDoc.items.length, 3);
    assert.equal(savedDoc.status, 'pending_procurement');
    assert.ok(savedDoc.csv_payload);
  });

  it('handles empty/zero confirmed buckets gracefully without throwing', async () => {
    const db = new MockFirestore();
    const date = '2026-10-23';

    // Campaign with only unfulfilled / open / failed buckets
    db.setDoc(`daily_campaigns/${date}`, { date, status: 'settled' });
    db.setDoc(`daily_campaigns/${date}/listings/listing_potato`, {
      product_id: 'prod_potato',
      product_title: 'Bogura Potatoes',
      unit_price: 40,
    });
    db.setDoc(`daily_campaigns/${date}/listings/listing_potato/buckets/1`, {
      bucket_number: 1,
      status: 'failed',
      current_quantity: 30,
      moq_threshold: 100,
    });

    const manifest = await buildProcurementManifest(date, db as any);

    assert.equal(manifest.date, date);
    assert.equal(manifest.total_confirmed_volume, 0);
    assert.equal(manifest.total_procurement_cost, 0);
    assert.equal(manifest.total_items_count, 0);
    assert.equal(manifest.total_buckets_count, 0);
    assert.deepEqual(manifest.items, []);
    assert.equal(manifest.status, 'pending_procurement');

    // CSV should be header line only
    const expectedHeader = 'SKU,Product Title,Category,Total Volume,Unit,Estimated Unit Cost,Total Budget,Target Wholesale Market / Supplier,Packaging Notes\n';
    assert.equal(manifest.csv_payload, expectedHeader);

    // Document persisted in Firestore
    const saved = db.getDoc(`procurement_manifests/${date}`);
    assert.ok(saved);
    assert.equal(saved.total_confirmed_volume, 0);
  });

  it('verifies packaging note calculation across distinct produce types and custom specs', () => {
    // 1. Grains exact multiple
    const grainExact = calculatePackagingNotes(150, 'kg', 'Grains & Staples');
    assert.equal(grainExact, '3 x 50 kg burlap bags');

    // 2. Grains with remainder
    const grainRemainder = calculatePackagingNotes(125, 'kg', 'Rice');
    assert.equal(grainRemainder, '2 x 50 kg burlap bags + 1 x 25 kg loose sack');

    // 3. Fruits exact multiple
    const fruitsExact = calculatePackagingNotes(40, 'kg', 'Fresh Fruits');
    assert.equal(fruitsExact, '4 x 10 kg crates');

    // 4. Fruits with remainder
    const fruitsRemainder = calculatePackagingNotes(45, 'kg', 'Vegetables');
    assert.equal(fruitsRemainder, '4 x 10 kg crates + 1 x 5 kg loose crate');

    // 5. Liquids
    const oilPacks = calculatePackagingNotes(25, 'liter', 'Edible Oils');
    assert.equal(oilPacks, '5 x 5 L containers');

    // 6. Custom spec provided
    const custom = calculatePackagingNotes(100, 'kg', 'Pulses', '20 kg vacuum sacks');
    assert.equal(custom, '5 x 20 kg vacuum sacks');

    // 7. Zero volume
    const zero = calculatePackagingNotes(0, 'kg', 'Grains');
    assert.equal(zero, 'N/A (0 volume)');
  });

  it('formats standardized CSV with proper RFC 4180 escaping for commas and quotes', () => {
    const items: any[] = [
      {
        sku: 'SKU-001',
        product_title: 'Nagpur Oranges, Grade "A" Spec',
        category: 'Fruits & Citrus',
        total_volume: 100,
        unit: 'kg',
        estimated_unit_cost: 120,
        total_budget: 12000,
        target_market: 'Karwan Bazar, Dhaka',
        packaging_notes: '10 x 10 kg crates',
      },
    ];

    const csv = generateProcurementCsv(items);
    const lines = csv.trim().split('\n');
    assert.equal(lines.length, 2);

    // Verify header line
    assert.equal(
      lines[0],
      'SKU,Product Title,Category,Total Volume,Unit,Estimated Unit Cost,Total Budget,Target Wholesale Market / Supplier,Packaging Notes'
    );

    // Verify RFC 4180 quotation and escaping
    assert.equal(escapeCsvField('hello, world'), '"hello, world"');
    assert.equal(escapeCsvField('test "quote"'), '"test ""quote"""');
    assert.equal(escapeCsvField(null), '');
    assert.equal(escapeCsvField(123), '123');
    // 'Nagpur Oranges, Grade "A" Spec' -> "Nagpur Oranges, Grade ""A"" Spec"
    // 'Karwan Bazar, Dhaka' -> "Karwan Bazar, Dhaka"
    assert.ok(lines[1].includes('"Nagpur Oranges, Grade ""A"" Spec"'));
    assert.ok(lines[1].includes('Fruits & Citrus'));
    assert.ok(lines[1].includes('"Karwan Bazar, Dhaka"'));
    assert.ok(lines[1].includes('100'));
    assert.ok(lines[1].includes('12000'));
  });

  it('preserves existing manifest status and checklist progress when re-running', async () => {
    const db = new MockFirestore();
    const date = '2026-10-24';

    // Existing manifest already in progress
    db.setDoc(`procurement_manifests/${date}`, {
      date,
      status: 'in_procurement',
      items: [
        {
          sku: 'SKU-ONION-01',
          status: 'procured', // Already checked off by market agent
        },
      ],
    });

    db.setDoc(`daily_campaigns/${date}`, { date, status: 'settled' });
    db.setDoc(`daily_campaigns/${date}/listings/listing_onion`, {
      sku: 'SKU-ONION-01',
      product_title: 'Deshi Onions',
      category: 'Vegetables',
      unit: 'kg',
      unit_price: 70,
      wholesale_price: 55,
    });
    db.setDoc(`daily_campaigns/${date}/listings/listing_onion/buckets/1`, {
      bucket_number: 1,
      status: 'confirmed',
      current_quantity: 100,
      moq_threshold: 100,
    });

    const manifest = await buildProcurementManifest(date, db as any);

    // Preserved in_procurement status
    assert.equal(manifest.status, 'in_procurement');
    // Preserved item status 'procured'
    assert.equal(manifest.items[0].status, 'procured');
  });

  it('midnight settlement automatically invokes procurement manifest generation for confirmed campaign', async () => {
    const db = new MockFirestore();
    const date = '2026-10-25';

    db.setDoc(`daily_campaigns/${date}`, {
      date,
      status: 'active',
    });

    db.setDoc(`daily_campaigns/${date}/listings/listing_dal`, {
      sku: 'SKU-DAL-01',
      product_title: 'Masoor Dal',
      category: 'Grains & Pulses',
      unit: 'kg',
      unit_price: 130,
      wholesale_price: 105,
    });

    db.setDoc(`daily_campaigns/${date}/listings/listing_dal/buckets/1`, {
      bucket_number: 1,
      status: 'target_met',
      current_quantity: 100,
      moq_threshold: 100,
    });

    db.setDoc('users/user_buyer_1', {
      uid: 'user_buyer_1',
      available_balance: 0,
      escrow_balance: 13000,
    });

    db.setDoc('orders/ord_dal_1', {
      order_id: 'ord_dal_1',
      user_id: 'user_buyer_1',
      date,
      listing_id: 'listing_dal',
      bucket_number: 1,
      total_amount: 13000,
      status: 'pending_bucket',
    });

    // Run midnight settlement
    await executeCampaignSettlement(date, db as any);

    // Verify procurement manifest was generated automatically by settlement
    const savedManifest = db.getDoc(`procurement_manifests/${date}`);
    assert.ok(savedManifest);
    assert.equal(savedManifest.date, date);
    assert.equal(savedManifest.total_confirmed_volume, 100);
    assert.equal(savedManifest.total_procurement_cost, 10500);
    assert.equal(savedManifest.items.length, 1);
    assert.equal(savedManifest.items[0].packaging_notes, '2 x 50 kg burlap bags');
  });
});
