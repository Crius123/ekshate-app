import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK singleton
if (!admin.apps.length) {
  admin.initializeApp();
}

export { placeOrder, onBucketTargetMet, executePlaceOrder, processBucketTargetMet } from './placeOrder';
export { settleDailyCampaign, manualSettleDailyCampaign } from './settleDailyCampaign';
export { syncListingToAlgolia, syncBucketToAlgolia, onCampaignActivated, getSearchToken } from './algoliaSync';
export {
  recordDepositTransaction,
  createDepositSession,
  executeBkashPayment,
  sslcommerzIpnWebhook,
} from './walletDeposits';
export {
  generateProcurementManifest,
  scheduledProcurementManifest,
  buildProcurementManifest,
  generateProcurementCsv,
  calculatePackagingNotes,
} from './generateProcurementManifest';
export {
  dispatchCampaignOrders,
  scheduledCampaignDispatch,
  executeCampaignDispatch,
  calculateParcelWeight,
  CourierGateway,
  PathaoCourierAdapter,
  SteadfastCourierAdapter,
  RedXCourierAdapter,
} from './courierDispatch';
export {
  onBucketUpdated,
  registerFcmToken,
  updateNotificationPreferences,
  sendTopicNotification,
  sendDirectUserNotification,
  checkAndTriggerUrgencyMilestone,
  notifyBucketTargetMet,
  notifySettlementConfirmed,
  notifySettlementRefund,
  notifyCourierDispatched,
  AdminMessagingAdapter,
  isCategoryEnabledForUser,
  DEFAULT_NOTIFICATION_PREFERENCES,
} from './notificationEngine';
export {
  createOrUpdateDailyCampaign,
  reviewWithdrawalRequest,
  getAdminOperationalMetrics,
  submitWithdrawalRequest,
  executeCreateOrUpdateDailyCampaign,
  executeReviewWithdrawalRequest,
  executeGetAdminOperationalMetrics,
  executeSubmitWithdrawalRequest,
  verifyAdminCaller,
} from './adminManagement';


