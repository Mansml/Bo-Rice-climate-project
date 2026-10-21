// =====================================================================
//  Bo District rice & climate project
//  STEP 1: Export the satellite data from Google Earth Engine
// ---------------------------------------------------------------------
//  How to use:
//   1. Go to https://code.earthengine.google.com and sign in.
//   2. Paste this whole file into the middle panel (the code editor).
//   3. Click "Run" (top of the editor).
//   4. Check the Console (right panel): the number of Bo polygons should be 1.
//   5. Open the "Tasks" tab (right panel). You will see 5 tasks.
//      Click "RUN" next to each one, then "Run" in the pop-up.
//   6. Wait. The rainfall task is the slowest (often 10-40 minutes).
//   7. When all tasks are blue/finished, open Google Drive, find the folder
//      "bo_rice_project", download all files, and put them in the
//      project's  data/raw/  folder.
//
//  Files you will get:
//   chirps_daily_bo_sle.csv     daily rainfall 1981-2025, Bo + all Sierra Leone
//   modis_ndvi_bo_cropland.csv  16-day vegetation index 2000-2025, Bo cropland
//   ndvi_bo_lateseason.tif      map of late-season greenness in Bo
//   districts_sle.geojson       district boundaries of Sierra Leone
//   boundary_bo.geojson         Bo District boundary
// =====================================================================


// ---------------------------------------------------------------------
// 1. STUDY AREA: Bo District and Sierra Leone
// ---------------------------------------------------------------------
// FAO GAUL is a global dataset of administrative boundaries.
// Level 0 = countries, level 2 = districts (in Sierra Leone).
var districts = ee.FeatureCollection('FAO/GAUL/2015/level2')
  .filter(ee.Filter.eq('ADM0_NAME', 'Sierra Leone'));

var bo = districts.filter(ee.Filter.eq('ADM2_NAME', 'Bo'));

var sle = ee.FeatureCollection('FAO/GAUL/2015/level0')
  .filter(ee.Filter.eq('ADM0_NAME', 'Sierra Leone'));

// Checks: Bo should be exactly 1 polygon. If it is 0, look at the list of
// names printed below and change 'Bo' above to the spelling used there.
print('Number of Bo polygons found (should be 1):', bo.size());
print('All district names in Sierra Leone:', districts.aggregate_array('ADM2_NAME'));

var boGeom  = bo.geometry();
var sleGeom = sle.geometry();

Map.centerObject(bo, 9);
Map.addLayer(sle, {color: '999999'}, 'Sierra Leone');
Map.addLayer(bo,  {color: 'e34948'}, 'Bo District');


// ---------------------------------------------------------------------
// 2. RAINFALL: CHIRPS daily, 1981-2025
// ---------------------------------------------------------------------
// CHIRPS combines satellite observations with rain-gauge data.
// One image per day, about 5 km resolution, values in mm/day.
var chirps = ee.ImageCollection('UCSB-CHG/CHIRPS/DAILY')
  .filterDate('1981-01-01', '2026-01-01')
  .select('precipitation');

// We average rainfall over two regions: Bo District and the whole country.
// (Bo is used for Parts A, B and D; the national average for Part C,
//  because the yield data are national.)
var regions = ee.FeatureCollection([
  ee.Feature(boGeom,  {region: 'Bo'}),
  ee.Feature(sleGeom, {region: 'Sierra Leone'})
]);

var rainTable = chirps.map(function (img) {
  var date = img.date().format('YYYY-MM-dd');
  var means = img.reduceRegions({
    collection: regions,
    reducer: ee.Reducer.mean(),
    scale: 5566            // CHIRPS pixel size in metres
  });
  return means.map(function (f) {
    return ee.Feature(null, {
      date: date,
      region: f.get('region'),
      rain_mm: f.get('mean')
    });
  });
}).flatten();

Export.table.toDrive({
  collection: rainTable,
  description: 'chirps_daily_bo_sle',
  folder: 'bo_rice_project',
  fileFormat: 'CSV',
  selectors: ['date', 'region', 'rain_mm']
});


// ---------------------------------------------------------------------
// 3. VEGETATION: MODIS NDVI and EVI, 16-day, 250 m, 2000-2025
// ---------------------------------------------------------------------
var modis = ee.ImageCollection('MODIS/061/MOD13Q1')
  .filterDate('2000-02-01', '2026-01-01');
var modisProj = modis.first().select('NDVI').projection();

// Farmland mask from ESA WorldCover (10 m, 2021).
// Class 40 = cropland, class 90 = herbaceous wetland (where much swamp
// rice is grown in inland valleys). We work out what fraction of each
// 250 m MODIS pixel is farmland and keep pixels that are at least half.
var worldcover = ee.ImageCollection('ESA/WorldCover/v200').first().select('Map');
var farm10m = worldcover.eq(40).or(worldcover.eq(90));

var farmFraction = farm10m
  .reduceResolution({reducer: ee.Reducer.mean(), maxPixels: 1024})
  .reproject({crs: modisProj});

var FARM_THRESHOLD = 0.5;   // lower to 0.3 if the pixel count below is very small
var farmMask = farmFraction.gte(FARM_THRESHOLD);

var nFarmPixels = farmMask.selfMask().reduceRegion({
  reducer: ee.Reducer.count(), geometry: boGeom, scale: 250, maxPixels: 1e10
}).values().get(0);
print('Farmland pixels in Bo at 250 m (ideally several hundred or more):', nFarmPixels);

var ndviTable = modis.map(function (img) {
  // SummaryQA: 0 = good, 1 = marginal, 2 = snow/ice, 3 = cloudy
  var good = img.select('SummaryQA').lte(1);
  var vi = img.select(['NDVI', 'EVI'])
    .multiply(0.0001)                 // stored as integers; convert to -1..1
    .updateMask(good)
    .updateMask(farmMask);
  var stats = vi.reduceRegion({
    reducer: ee.Reducer.mean().combine(ee.Reducer.count(), null, true),
    geometry: boGeom,
    scale: 250,
    crs: modisProj,
    maxPixels: 1e10
  });
  return ee.Feature(null, {
    date: img.date().format('YYYY-MM-dd'),
    ndvi: stats.get('NDVI_mean'),
    evi: stats.get('EVI_mean'),
    n_good_pixels: stats.get('NDVI_count'),
    n_farm_pixels: nFarmPixels
  });
});

Export.table.toDrive({
  collection: ndviTable,
  description: 'modis_ndvi_bo_cropland',
  folder: 'bo_rice_project',
  fileFormat: 'CSV',
  selectors: ['date', 'ndvi', 'evi', 'n_good_pixels', 'n_farm_pixels']
});


// ---------------------------------------------------------------------
// 4. MAP: late-season greenness in Bo (Oct-Dec, 2015-2025)
// ---------------------------------------------------------------------
// Two bands: median NDVI, and the farmland fraction of each pixel.
var ndviLate = modis
  .filterDate('2015-01-01', '2026-01-01')
  .filter(ee.Filter.calendarRange(10, 12, 'month'))
  .map(function (img) {
    return img.select('NDVI').multiply(0.0001)
      .updateMask(img.select('SummaryQA').lte(1));
  })
  .median()
  .rename('ndvi');

var mapImage = ndviLate.addBands(farmFraction.rename('farm_fraction'))
  .toFloat()
  .clip(boGeom);

Map.addLayer(ndviLate.clip(boGeom), {min: 0.3, max: 0.9,
  palette: ['f3ecd9', 'a8c97f', '2f7d32']}, 'Late-season NDVI');

Export.image.toDrive({
  image: mapImage,
  description: 'ndvi_bo_lateseason',
  folder: 'bo_rice_project',
  region: boGeom,
  scale: 250,
  crs: 'EPSG:4326',
  maxPixels: 1e10
});


// ---------------------------------------------------------------------
// 5. BOUNDARIES for maps in R
// ---------------------------------------------------------------------
Export.table.toDrive({
  collection: districts.select(['ADM1_NAME', 'ADM2_NAME']),
  description: 'districts_sle',
  folder: 'bo_rice_project',
  fileFormat: 'GeoJSON'
});

Export.table.toDrive({
  collection: bo.select(['ADM2_NAME']),
  description: 'boundary_bo',
  folder: 'bo_rice_project',
  fileFormat: 'GeoJSON'
});
