/**
 * Algolia Index Schema Configuration for Ekshate Daily Listings
 */
export const LISTINGS_INDEX_SETTINGS = {
  searchableAttributes: [
    'unordered(product_title)',
    'unordered(category)',
    'description',
    'unit',
  ],
  attributesForFaceting: [
    'filterOnly(status)',
    'filterOnly(date)',
    'category',
    'filterOnly(product_id)',
  ],
  customRanking: [
    'desc(total_volume_ordered)',
    'desc(discount_percent)',
    'asc(unit_price)',
  ],
  attributesToHighlight: [
    'product_title',
    'category',
  ],
  unretrievableAttributes: [
    'supplier_cost_price',
    'admin_notes',
  ],
  minWordSizefor1Typo: 4,
  minWordSizefor2Typos: 8,
  allowTyposOnNumericTokens: false,
};
