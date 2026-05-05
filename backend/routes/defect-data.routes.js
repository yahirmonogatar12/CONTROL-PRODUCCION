/**
 * Defect Data Routes - Lookup en tabla externa defect_data
 */

const router = require('express').Router();
const ctrl = require('../controllers/defect-data.controller');

// GET /api/defect-data/lookup?codigo=XYZ
router.get('/lookup', ctrl.lookup);

module.exports = router;
