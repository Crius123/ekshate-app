import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK singleton
if (!admin.apps.length) {
  admin.initializeApp();
}

export { placeOrder, onBucketTargetMet } from './placeOrder';
export { settleDailyCampaign, manualSettleDailyCampaign } from './settleDailyCampaign';
export { syncListingToAlgolia, onCampaignActivated, getSearchToken } from './algoliaSync';
