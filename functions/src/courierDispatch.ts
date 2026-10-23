import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getDhakaDateString } from './settleDailyCampaign';

export type CourierPartner = 'pathao' | 'steadfast' | 'redx';

export interface CourierCredentials {
  apiKey?: string;
  apiSecret?: string;
  clientId?: string;
  clientSecret?: string;
  accessToken?: string;
  storeId?: number | string;
  baseUrl?: string;
}

export interface NormalizedBookingPayload {
  orderId: string;
  recipientName: string;
  recipientPhone: string;
  recipientAddress: string;
  recipientCity?: string;
  recipientZone?: string;
  recipientArea?: string;
  packageWeightKg: number;
  itemDescription: string;
  itemQuantity: number;
  totalOrderAmount: number;
  amountToCollect: number; // For pre-paid Ekshate bulk orders, amountToCollect is 0
  specialInstructions?: string;
}

export interface ConsignmentResult {
  success: boolean;
  courierPartner: CourierPartner;
  consignmentId: string;
  trackingCode: string;
  trackingUrl: string;
  deliveryFee: number;
  rawResponse?: any;
  error?: string;
}

/**
 * Computes volumetric & packaging parcel weight from item quantity, unit, and product metadata.
 * Clamps to a minimum billable courier weight of 0.5 kg.
 */
export function calculateParcelWeight(
  quantity: number,
  unit: string,
  category?: string,
  productTitle?: string
): number {
  const normUnit = (unit || '').toLowerCase().trim();
  const normTitle = (productTitle || '').toLowerCase();
  const normCategory = (category || '').toLowerCase();

  let weight = 0;

  // 1. Direct units: kg, gram/g, liter/l
  if (normUnit === 'kg' || normUnit === 'kilogram' || normUnit === 'kgs') {
    weight = quantity * 1.0;
  } else if (normUnit === 'g' || normUnit === 'gram' || normUnit === 'grams' || normUnit === 'gm') {
    weight = (quantity * 1.0) / 1000.0;
  } else if (normUnit === 'l' || normUnit === 'liter' || normUnit === 'litre' || normUnit === 'liters') {
    // 1 Liter produce/oil ~= 1.0 kg courier volumetric equivalent
    weight = quantity * 1.0;
  } else if (normUnit.includes('bag') || normUnit.includes('sack')) {
    // Check product title for pack size, e.g., "Miniket Premium Rice (25 kg bag)"
    const match = normTitle.match(/(\d+(?:\.\d+)?)\s*kg/i);
    const unitWeight = match ? parseFloat(match[1]) : 25.0; // Default bulk sack: 25 kg
    weight = quantity * unitWeight;
  } else if (normUnit.includes('jar') || normUnit.includes('tin') || normUnit.includes('can') || normUnit.includes('bottle')) {
    // Check product title, e.g. "Pure Mustard Oil (5 L jar)"
    const match = normTitle.match(/(\d+(?:\.\d+)?)\s*(?:l|liter|kg)/i);
    const unitWeight = match ? parseFloat(match[1]) : 5.0; // Default jar/tin: 5 L (~5 kg)
    weight = quantity * unitWeight;
  } else if (normUnit.includes('crate') || normUnit.includes('box')) {
    // Check product title, e.g. "Alphonso Mango (10 kg crate)"
    const match = normTitle.match(/(\d+(?:\.\d+)?)\s*kg/i);
    const unitWeight = match ? parseFloat(match[1]) : 10.0; // Default produce crate: 10 kg
    weight = quantity * unitWeight;
  } else {
    // Inspect title for embedded packaging weights, e.g. "Tata Salt (1 kg packet)", "Saffron (10 g)"
    const match = normTitle.match(/(\d+(?:\.\d+)?)\s*(kg|g|gm|liter|l|ml)/i);
    if (match) {
      const val = parseFloat(match[1]);
      const specUnit = match[2].toLowerCase();
      if (specUnit === 'kg' || specUnit === 'l' || specUnit === 'liter') {
        weight = quantity * val;
      } else if (specUnit === 'g' || specUnit === 'gm' || specUnit === 'ml') {
        weight = (quantity * val) / 1000.0;
      }
    } else {
      // Heuristic fallback based on category
      if (normCategory.includes('rice') || normCategory.includes('flour') || normCategory.includes('grain')) {
        weight = quantity * 1.0;
      } else if (normCategory.includes('oil') || normCategory.includes('liquid')) {
        weight = quantity * 1.0;
      } else {
        weight = quantity * 1.0;
      }
    }
  }

  // Couriers in Bangladesh (Pathao, Steadfast, RedX) enforce a minimum billable weight of 0.5 kg
  const finalWeight = Math.max(0.5, Math.round(weight * 100) / 100);
  return finalWeight;
}

// ---------------------------------------------------------------------------
// Courier Adapter Interface & Normalizers
// ---------------------------------------------------------------------------

export interface CourierAdapter {
  readonly partner: CourierPartner;
  formatPayload(payload: NormalizedBookingPayload): any;
  createConsignment(payload: NormalizedBookingPayload): Promise<ConsignmentResult>;
}

/**
 * Pathao Courier API v2 Adapter
 * Documentation / Spec: https://courier-api-bi.pathao.com
 */
export class PathaoCourierAdapter implements CourierAdapter {
  readonly partner: CourierPartner = 'pathao';

  constructor(
    private config: CourierCredentials = {},
    private mockMode: boolean = true
  ) {}

  formatPayload(payload: NormalizedBookingPayload): any {
    return {
      store_id: this.config.storeId || 1001,
      merchant_order_id: payload.orderId,
      recipient_name: payload.recipientName,
      recipient_phone: payload.recipientPhone,
      recipient_address: payload.recipientAddress,
      recipient_city: payload.recipientCity || 1, // Dhaka
      recipient_zone: payload.recipientZone || 1,
      recipient_area: payload.recipientArea || 1,
      delivery_type: 48, // 48-hour delivery standard
      item_type: 2, // 2 = Parcel (1 = Document)
      special_instruction: payload.specialInstructions || 'Handle with care - Ekshate Wholesale Produce',
      item_quantity: Math.max(1, Math.round(payload.itemQuantity)),
      item_weight: payload.packageWeightKg,
      amount_to_collect: payload.amountToCollect,
      item_description: payload.itemDescription,
    };
  }

  async createConsignment(payload: NormalizedBookingPayload): Promise<ConsignmentResult> {
    const rawPayload = this.formatPayload(payload);

    if (this.mockMode || !this.config.apiKey) {
      // Mock consignment generation
      const cleanId = payload.orderId.replace(/[^a-zA-Z0-9]/g, '');
      const consignmentId = `PTH-CON-${cleanId}`;
      const trackingCode = `PTH-TRK-${cleanId}`;
      const trackingUrl = `https://pathao.com/courier/tracking/?consignment_id=${consignmentId}`;
      // Base fee 60 BDT for first 1kg, + 20 BDT per additional kg
      const deliveryFee = 60 + Math.max(0, Math.ceil(payload.packageWeightKg - 1)) * 20;

      return {
        success: true,
        courierPartner: 'pathao',
        consignmentId,
        trackingCode,
        trackingUrl,
        deliveryFee,
        rawResponse: {
          type: 'success',
          code: 200,
          message: 'Order created successfully (Mock)',
          data: {
            consignment_id: consignmentId,
            merchant_order_id: payload.orderId,
            order_status: 'Order Placed',
            delivery_fee: deliveryFee,
          },
        },
      };
    }

    // Live HTTP booking integration
    const baseUrl = this.config.baseUrl || 'https://courier-api-bi.pathao.com';
    const response = await fetch(`${baseUrl}/aladdin/api/v1/orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${this.config.accessToken || this.config.apiKey}`,
      },
      body: JSON.stringify(rawPayload),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Pathao API error (${response.status}): ${errText}`);
    }

    const data: any = await response.json();
    const consignmentId = data?.data?.consignment_id || `PTH-${payload.orderId}`;
    return {
      success: true,
      courierPartner: 'pathao',
      consignmentId,
      trackingCode: `PTH-TRK-${consignmentId}`,
      trackingUrl: `https://pathao.com/courier/tracking/?consignment_id=${consignmentId}`,
      deliveryFee: data?.data?.delivery_fee || 60,
      rawResponse: data,
    };
  }
}

/**
 * Steadfast Courier API Adapter
 * Documentation / Spec: https://portal.steadfast.com.bd/api/v1
 */
export class SteadfastCourierAdapter implements CourierAdapter {
  readonly partner: CourierPartner = 'steadfast';

  constructor(
    private config: CourierCredentials = {},
    private mockMode: boolean = true
  ) {}

  formatPayload(payload: NormalizedBookingPayload): any {
    return {
      invoice: payload.orderId,
      recipient_name: payload.recipientName,
      recipient_phone: payload.recipientPhone,
      recipient_address: payload.recipientAddress,
      cod_amount: payload.amountToCollect,
      note: `${payload.itemDescription} (${payload.packageWeightKg} kg). ${payload.specialInstructions || 'Handle with care'}`.trim(),
    };
  }

  async createConsignment(payload: NormalizedBookingPayload): Promise<ConsignmentResult> {
    const rawPayload = this.formatPayload(payload);

    if (this.mockMode || !this.config.apiKey) {
      const cleanId = payload.orderId.replace(/[^a-zA-Z0-9]/g, '');
      const consignmentId = `SF-CON-${cleanId}`;
      const trackingCode = `SF-TRK-${cleanId}`;
      const trackingUrl = `https://steadfast.com.bd/t/${trackingCode}`;
      // Base fee 70 BDT for first 1kg, + 15 BDT per additional kg
      const deliveryFee = 70 + Math.max(0, Math.ceil(payload.packageWeightKg - 1)) * 15;

      return {
        success: true,
        courierPartner: 'steadfast',
        consignmentId,
        trackingCode,
        trackingUrl,
        deliveryFee,
        rawResponse: {
          status: 200,
          message: 'Order created successfully (Mock)',
          consignment: {
            consignment_id: consignmentId,
            invoice: payload.orderId,
            tracking_code: trackingCode,
            status: 'in_review',
          },
        },
      };
    }

    const baseUrl = this.config.baseUrl || 'https://portal.steadfast.com.bd/api/v1';
    const response = await fetch(`${baseUrl}/create_order`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Api-Key': this.config.apiKey || '',
        'Secret-Key': this.config.apiSecret || '',
      },
      body: JSON.stringify(rawPayload),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Steadfast API error (${response.status}): ${errText}`);
    }

    const data: any = await response.json();
    const consignment = data?.consignment || {};
    return {
      success: true,
      courierPartner: 'steadfast',
      consignmentId: consignment.consignment_id || `SF-${payload.orderId}`,
      trackingCode: consignment.tracking_code || `SF-TRK-${payload.orderId}`,
      trackingUrl: `https://steadfast.com.bd/t/${consignment.tracking_code || consignment.consignment_id}`,
      deliveryFee: 70,
      rawResponse: data,
    };
  }
}

/**
 * RedX Courier API Adapter
 * Documentation / Spec: https://openapi.redx.com.bd
 */
export class RedXCourierAdapter implements CourierAdapter {
  readonly partner: CourierPartner = 'redx';

  constructor(
    private config: CourierCredentials = {},
    private mockMode: boolean = true
  ) {}

  formatPayload(payload: NormalizedBookingPayload): any {
    return {
      customer_name: payload.recipientName,
      customer_phone: payload.recipientPhone,
      customer_address: payload.recipientAddress,
      delivery_area: payload.recipientCity || 'Dhaka',
      delivery_area_id: 1,
      merchant_invoice_id: payload.orderId,
      cash_collection_amount: payload.amountToCollect,
      parcel_weight: Math.round(payload.packageWeightKg * 1000), // grams for RedX
      instruction: payload.specialInstructions || 'Handle with care - Ekshate Wholesale Produce',
      value: payload.totalOrderAmount,
      parcel_details: [
        {
          name: payload.itemDescription,
          quantity: payload.itemQuantity,
          weight: payload.packageWeightKg,
        },
      ],
    };
  }

  async createConsignment(payload: NormalizedBookingPayload): Promise<ConsignmentResult> {
    const rawPayload = this.formatPayload(payload);

    if (this.mockMode || !this.config.apiKey) {
      const cleanId = payload.orderId.replace(/[^a-zA-Z0-9]/g, '');
      const consignmentId = `REDX-CON-${cleanId}`;
      const trackingCode = `REDX-TRK-${cleanId}`;
      const trackingUrl = `https://redx.com.bd/track-parcel/?trackingId=${trackingCode}`;
      // Base fee 65 BDT for first 1kg, + 18 BDT per additional kg
      const deliveryFee = 65 + Math.max(0, Math.ceil(payload.packageWeightKg - 1)) * 18;

      return {
        success: true,
        courierPartner: 'redx',
        consignmentId,
        trackingCode,
        trackingUrl,
        deliveryFee,
        rawResponse: {
          tracking_id: trackingCode,
          parcel: {
            id: consignmentId,
            tracking_id: trackingCode,
            invoice_id: payload.orderId,
          },
        },
      };
    }

    const baseUrl = this.config.baseUrl || 'https://openapi.redx.com.bd';
    const response = await fetch(`${baseUrl}/v1.0.0-beta/parcels`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'API-ACCESS-TOKEN': `Bearer ${this.config.apiKey || this.config.accessToken}`,
      },
      body: JSON.stringify(rawPayload),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`RedX API error (${response.status}): ${errText}`);
    }

    const data: any = await response.json();
    const trackingId = data?.tracking_id || `REDX-TRK-${payload.orderId}`;
    return {
      success: true,
      courierPartner: 'redx',
      consignmentId: data?.parcel?.id || trackingId,
      trackingCode: trackingId,
      trackingUrl: `https://redx.com.bd/track-parcel/?trackingId=${trackingId}`,
      deliveryFee: 65,
      rawResponse: data,
    };
  }
}

// ---------------------------------------------------------------------------
// Unified Courier Gateway & Fallback Orchestration
// ---------------------------------------------------------------------------

export interface CourierGatewayOptions {
  mockMode?: boolean;
  primaryCourier?: CourierPartner;
  pathaoConfig?: CourierCredentials;
  steadfastConfig?: CourierCredentials;
  redxConfig?: CourierCredentials;
  simulatedFailures?: Partial<Record<CourierPartner, boolean>>;
}

export class CourierGateway {
  private adapters: Map<CourierPartner, CourierAdapter> = new Map();
  private simulatedFailures: Map<CourierPartner, boolean> = new Map();
  private primaryCourier: CourierPartner;

  constructor(options: CourierGatewayOptions = {}) {
    const mock = options.mockMode !== undefined ? options.mockMode : true;
    this.primaryCourier = options.primaryCourier || 'pathao';

    this.registerAdapter(new PathaoCourierAdapter(options.pathaoConfig, mock));
    this.registerAdapter(new SteadfastCourierAdapter(options.steadfastConfig, mock));
    this.registerAdapter(new RedXCourierAdapter(options.redxConfig, mock));

    if (options.simulatedFailures) {
      for (const [k, v] of Object.entries(options.simulatedFailures)) {
        if (v !== undefined) {
          this.simulatedFailures.set(k as CourierPartner, v);
        }
      }
    }
  }

  registerAdapter(adapter: CourierAdapter) {
    this.adapters.set(adapter.partner, adapter);
  }

  getAdapter(partner: CourierPartner): CourierAdapter | undefined {
    return this.adapters.get(partner);
  }

  simulateFailure(partner: CourierPartner, shouldFail: boolean) {
    this.simulatedFailures.set(partner, shouldFail);
  }

  /**
   * Researches and builds normalized fallback chain:
   * e.g., preferred -> remaining in priority order ['pathao', 'steadfast', 'redx']
   */
  getFallbackChain(preferredPartner?: CourierPartner): CourierPartner[] {
    const defaultPriority: CourierPartner[] = ['pathao', 'steadfast', 'redx'];
    const chosen = preferredPartner || this.primaryCourier;
    const chain: CourierPartner[] = [chosen];
    for (const p of defaultPriority) {
      if (!chain.includes(p)) {
        chain.push(p);
      }
    }
    return chain;
  }

  /**
   * Books consignment with automatic fallback across couriers.
   * If primary partner fails/errors out, tries secondary courier seamlessly.
   */
  async bookConsignment(
    payload: NormalizedBookingPayload,
    preferredPartner?: CourierPartner,
    customFallbackChain?: CourierPartner[]
  ): Promise<ConsignmentResult> {
    const chain = customFallbackChain || this.getFallbackChain(preferredPartner);
    const failureLogs: Array<{ partner: CourierPartner; error: string }> = [];

    for (const partner of chain) {
      const adapter = this.adapters.get(partner);
      if (!adapter) {
        failureLogs.push({ partner, error: `Adapter not registered for ${partner}` });
        continue;
      }

      if (this.simulatedFailures.get(partner)) {
        failureLogs.push({ partner, error: `Simulated gateway outage / API timeout on ${partner}` });
        continue;
      }

      try {
        const result = await adapter.createConsignment(payload);
        if (result && result.success) {
          return {
            ...result,
            courierPartner: partner,
          };
        } else {
          failureLogs.push({ partner, error: result?.error || 'Booking returned unsuccess' });
        }
      } catch (err: any) {
        failureLogs.push({ partner, error: err?.message || String(err) });
      }
    }

    // If all couriers failed
    const errorDetails = failureLogs.map((f) => `[${f.partner}]: ${f.error}`).join(' | ');
    return {
      success: false,
      courierPartner: preferredPartner || this.primaryCourier,
      consignmentId: '',
      trackingCode: '',
      trackingUrl: '',
      deliveryFee: 0,
      error: `All couriers in fallback chain failed: ${errorDetails}`,
    };
  }
}

// ---------------------------------------------------------------------------
// Cloud Function Core Engine: executeCampaignDispatch
// ---------------------------------------------------------------------------

export interface DispatchCampaignOptions {
  date?: string;
  preferredCourier?: CourierPartner;
  gateway?: CourierGateway;
  db?: any;
  dryRun?: boolean;
  batchChunkSize?: number;
}

export interface DispatchedOrderSummary {
  orderId: string;
  courierPartner: CourierPartner;
  consignmentId: string;
  trackingCode: string;
  trackingUrl: string;
  parcelWeightKg: number;
  deliveryFee: number;
}

export interface DispatchCampaignReport {
  date: string;
  totalOrders: number;
  dispatchedCount: number;
  failedCount: number;
  alreadyDispatchedCount: number;
  totalWeightKg: number;
  totalDeliveryFees: number;
  dispatchedOrders: DispatchedOrderSummary[];
  errors: Array<{ orderId: string; error: string }>;
}

/**
 * Core dispatch engine: queries confirmed orders for the campaign date,
 * calculates parcel package weights, books consignments across courier gateway,
 * and updates Firestore orders with consignment tracking fields in batches.
 */
export async function executeCampaignDispatch(
  options: DispatchCampaignOptions = {}
): Promise<DispatchCampaignReport> {
  const db = options.db || admin.firestore();
  const campaignDate = options.date || getDhakaDateString();
  const gateway = options.gateway || new CourierGateway({ mockMode: true });
  const preferredCourier = options.preferredCourier || 'pathao';
  const dryRun = !!options.dryRun;
  const chunkSize = options.batchChunkSize || 50;

  // 1. Query confirmed orders for the campaign date
  const ordersSnap = await db
    .collection('orders')
    .where('date', '==', campaignDate)
    .where('status', '==', 'confirmed')
    .get();

  const report: DispatchCampaignReport = {
    date: campaignDate,
    totalOrders: ordersSnap.size,
    dispatchedCount: 0,
    failedCount: 0,
    alreadyDispatchedCount: 0,
    totalWeightKg: 0,
    totalDeliveryFees: 0,
    dispatchedOrders: [],
    errors: [],
  };

  if (ordersSnap.empty) {
    return report;
  }

  // 2. Filter out any already dispatched (idempotency safety)
  const ordersToDispatch: Array<{ id: string; ref: any; data: any }> = [];
  for (const doc of ordersSnap.docs) {
    const data = doc.data();
    if (data.status === 'dispatched' || data.consignment_id) {
      report.alreadyDispatchedCount++;
    } else {
      ordersToDispatch.push({ id: doc.id, ref: doc.ref, data });
    }
  }

  // 3. Process orders in batches to comply with Firestore write limits
  for (let i = 0; i < ordersToDispatch.length; i += chunkSize) {
    const chunk = ordersToDispatch.slice(i, i + chunkSize);
    const chunkUpdates: Array<{ ref: any; updateData: any }> = [];

    for (const item of chunk) {
      const order = item.data;
      const orderId = order.order_id || item.id;

      // Volumetric weight calculation
      const weightKg = calculateParcelWeight(
        Number(order.quantity) || 1,
        order.unit || 'kg',
        order.category,
        order.product_title
      );

      const bookingPayload: NormalizedBookingPayload = {
        orderId,
        recipientName: order.user_name || order.user_phone || 'Valued Buyer',
        recipientPhone: order.user_phone || '+8801700000000',
        recipientAddress: order.delivery_address || 'Dhaka, Bangladesh',
        recipientCity: 'Dhaka',
        packageWeightKg: weightKg,
        itemDescription: `${order.product_title || 'Ekshate Produce'} (${order.quantity} ${order.unit})`,
        itemQuantity: Number(order.quantity) || 1,
        totalOrderAmount: Number(order.total_amount) || 0,
        amountToCollect: 0, // 0 for Ekshate pre-paid bulk orders
        specialInstructions: 'Morning wholesale batch delivery - Ekshate',
      };

      // Reserve consignment via gateway
      const bookingResult = await gateway.bookConsignment(bookingPayload, preferredCourier);

      if (bookingResult.success) {
        const updateData: any = {
          status: 'dispatched',
          courier_partner: bookingResult.courierPartner,
          consignment_id: bookingResult.consignmentId,
          tracking_code: bookingResult.trackingCode,
          tracking_url: bookingResult.trackingUrl,
          parcel_weight_kg: weightKg,
          delivery_fee: bookingResult.deliveryFee,
          dispatched_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        };

        chunkUpdates.push({ ref: item.ref, updateData });

        report.dispatchedCount++;
        report.totalWeightKg = +(report.totalWeightKg + weightKg).toFixed(2);
        report.totalDeliveryFees = +(report.totalDeliveryFees + bookingResult.deliveryFee).toFixed(2);
        report.dispatchedOrders.push({
          orderId,
          courierPartner: bookingResult.courierPartner,
          consignmentId: bookingResult.consignmentId,
          trackingCode: bookingResult.trackingCode,
          trackingUrl: bookingResult.trackingUrl,
          parcelWeightKg: weightKg,
          deliveryFee: bookingResult.deliveryFee,
        });
      } else {
        report.failedCount++;
        report.errors.push({
          orderId,
          error: bookingResult.error || 'Courier booking failed',
        });
      }
    }

    // Persist chunk to Firestore (unless dryRun)
    if (!dryRun && chunkUpdates.length > 0) {
      if (typeof db.batch === 'function') {
        const batch = db.batch();
        for (const cu of chunkUpdates) {
          batch.update(cu.ref, cu.updateData);
        }
        await batch.commit();
      } else {
        // Fallback for custom mocks without batch
        for (const cu of chunkUpdates) {
          await cu.ref.update(cu.updateData);
        }
      }

      // Notify buyers of courier dispatch
      try {
        const { notifyCourierDispatched } = await import('./notificationEngine');
        for (const cu of chunkUpdates) {
          const matchingOrder = chunk.find((c) => (c.ref.path || c.id) === (cu.ref.path || cu.ref.id));
          if (matchingOrder) {
            await notifyCourierDispatched(
              matchingOrder.data,
              {
                courierPartner: cu.updateData.courier_partner,
                trackingCode: cu.updateData.tracking_code,
                trackingUrl: cu.updateData.tracking_url,
              },
              db
            );
          }
        }
      } catch (notifErr) {
        console.error('Error sending courier dispatch notifications:', notifErr);
      }
    }
  }

  // Record dispatch batch manifest in dispatch_batches/{campaignDate}
  if (!dryRun && report.dispatchedCount > 0) {
    try {
      await db.collection('dispatch_batches').doc(campaignDate).set(
        {
          date: campaignDate,
          dispatched_at: admin.firestore.FieldValue.serverTimestamp(),
          total_orders: report.totalOrders,
          dispatched_count: report.dispatchedCount,
          failed_count: report.failedCount,
          already_dispatched_count: report.alreadyDispatchedCount,
          total_weight_kg: report.totalWeightKg,
          total_delivery_fees: report.totalDeliveryFees,
          preferred_courier: preferredCourier,
          status: report.failedCount === 0 ? 'completed' : 'partial_failure',
        },
        { merge: true }
      );
    } catch (e: any) {
      console.warn(`Could not save dispatch_batches/${campaignDate}:`, e?.message);
    }
  }

  return report;
}

// ---------------------------------------------------------------------------
// Cloud Functions Exports
// ---------------------------------------------------------------------------

/**
 * Callable Cloud Function: dispatchCampaignOrders
 * Invoked by dispatch managers or client app to book courier consignments for a campaign date.
 */
export const dispatchCampaignOrders = onCall(
  { region: 'asia-east1', enforceAppCheck: false },
  async (request) => {
    const { date, preferredCourier, dryRun } = request.data || {};
    try {
      const summary = await executeCampaignDispatch({
        date,
        preferredCourier,
        dryRun: !!dryRun,
      });
      return summary;
    } catch (error: any) {
      throw new HttpsError('internal', `Failed to dispatch campaign orders: ${error?.message || error}`);
    }
  }
);

/**
 * Scheduled Cloud Function: scheduledCampaignDispatch
 * Triggers every morning at 9:00 AM BDT (03:00 UTC) post-procurement manifest.
 */
export const scheduledCampaignDispatch = onSchedule(
  {
    schedule: '0 3 * * *', // 9:00 AM BDT
    timeZone: 'Asia/Dhaka',
    region: 'asia-east1',
  },
  async () => {
    const today = getDhakaDateString();
    console.log(`[Scheduled Dispatch] Executing automated courier dispatch for ${today}`);
    const summary = await executeCampaignDispatch({ date: today });
    console.log(`[Scheduled Dispatch] Completed:`, {
      date: summary.date,
      dispatched: summary.dispatchedCount,
      failed: summary.failedCount,
      totalWeight: summary.totalWeightKg,
    });
  }
);
