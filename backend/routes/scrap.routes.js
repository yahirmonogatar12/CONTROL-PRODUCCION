/**
 * Scrap Routes - Registro de scrap por escaneo QR
 */
const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/scrap.controller');

router.post('/scan', ctrl.scan);
router.get('/records', ctrl.getRecords);
router.get('/autocomplete', ctrl.autocomplete);
router.delete('/record/:id', ctrl.deleteRecord);

module.exports = router;
