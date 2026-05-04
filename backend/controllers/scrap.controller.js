/**
 * Scrap Controller - Registro de scrap por escaneo QR
 * Areas: SMD, IMD, Assy, Componente, Mantenimiento
 * QR Format: TOKEN0;ASSY_TYPE;PART_NO;TOKEN3 (mismo formato PCB)
 */

const { pool, getMexicoDateTime, getMexicoDate } = require('../config/database');

// ============================================
// HELPERS
// ============================================

function normalizeCode(code) {
  return (code || '').trim().toUpperCase().replace(/\s+/g, '');
}

function parseScannedCode(code) {
  const parts = code.split(';').map(s => s.trim()).filter(Boolean);
  // Si no tiene separadores (entrada manual sin QR), tratar todo como part_no
  if (parts.length <= 1) {
    return {
      token0: null,
      assy_type: null,
      part_no: parts[0] || null,
      token3: null,
    };
  }
  return {
    token0: parts[0] || null,
    assy_type: parts[1] || null,
    part_no: parts[2] || null,
    token3: parts[3] || null,
  };
}

async function lookupModelo(partNo) {
  if (!partNo) return 'N/A';
  try {
    // Buscar project (modelo) en tabla raw por part_no
    const [rows] = await pool.query(
      `SELECT DISTINCT project FROM raw WHERE part_no = ? AND project IS NOT NULL AND project != '' LIMIT 1`,
      [partNo]
    );
    if (rows.length > 0 && rows[0].project) {
      return rows[0].project;
    }
    return 'N/A';
  } catch (_err) {
    return 'N/A';
  }
}

const VALID_AREAS = ['M1', 'M2', 'M3', 'M4', 'D1', 'D2', 'D3', 'CALIDAD', 'MANTENIMIENTO', 'SMD', 'IMD', 'IPM', 'COATING', 'PROVEEDOR', 'COMPONENTE'];

// ============================================
// POST /api/scrap/scan
// Registra un escaneo de scrap
// ============================================
exports.scan = async (req, res, next) => {
  try {
    const { scanned_code, area, motivo_scrap_id, comentarios, usuario } = req.body;

    if (!scanned_code || !scanned_code.trim()) {
      return res.status(400).json({
        success: false,
        message: 'scanned_code es requerido',
        code: 'MISSING_SCANNED_CODE',
      });
    }

    if (!area || !VALID_AREAS.includes(area)) {
      return res.status(400).json({
        success: false,
        message: `area es requerida y debe ser una de: ${VALID_AREAS.join(', ')}`,
        code: 'INVALID_AREA',
      });
    }

    if (!motivo_scrap_id) {
      return res.status(400).json({
        success: false,
        message: 'motivo_scrap_id es requerido',
        code: 'MISSING_MOTIVO',
      });
    }

    // Parsear QR
    const parsed = parseScannedCode(scanned_code.trim());
    const scannedOriginal = scanned_code.trim();
    const scannedOriginalNorm = normalizeCode(scanned_code);
    const fechaHoy = getMexicoDate();

    // Verificar duplicado (mismo codigo + misma fecha)
    const [existing] = await pool.query(
      `SELECT id FROM scrap_records 
       WHERE scanned_original_norm = ? AND DATE(fecha_registro) = ?`,
      [scannedOriginalNorm, fechaHoy]
    );

    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Este codigo ya fue registrado como scrap hoy',
        code: 'DUPLICATE_SCAN',
        existing_id: existing[0].id,
      });
    }

    // Obtener texto del motivo
    let motivoTexto = '';
    const [motivoRows] = await pool.query(
      `SELECT motivo FROM scrap_motivos WHERE id = ? AND activo = 1`,
      [motivo_scrap_id]
    );
    if (motivoRows.length > 0) {
      motivoTexto = motivoRows[0].motivo;
    } else {
      return res.status(400).json({
        success: false,
        message: 'Motivo de scrap no encontrado o inactivo',
        code: 'INVALID_MOTIVO',
      });
    }

    // Buscar modelo (project) en tabla raw
    const modelo = await lookupModelo(parsed.part_no);

    // Si entrada manual (sin QR), intentar llenar assy_type desde raw.model
    let assyType = parsed.assy_type;
    if (!assyType && parsed.part_no) {
      try {
        const [rawRows] = await pool.query(
          `SELECT model FROM raw WHERE part_no = ? AND model IS NOT NULL LIMIT 1`,
          [parsed.part_no]
        );
        if (rawRows.length > 0 && rawRows[0].model) {
          assyType = rawRows[0].model;
        }
      } catch (_) {}
    }

    const ahora = getMexicoDateTime();

    const [result] = await pool.query(
      `INSERT INTO scrap_records 
        (scanned_original, scanned_original_norm, assy_type, part_no, modelo, area, motivo_scrap_id, motivo_scrap_texto, comentarios, usuario_registro, fecha_registro)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        scannedOriginal,
        scannedOriginalNorm,
        assyType || null,
        parsed.part_no,
        modelo,
        area,
        motivo_scrap_id,
        motivoTexto,
        comentarios || null,
        usuario || null,
        ahora,
      ]
    );

    const [inserted] = await pool.query(
      `SELECT *, DATE_FORMAT(fecha_registro, '%Y-%m-%d') as fecha, 
              DATE_FORMAT(fecha_registro, '%H:%i:%s') as hora
       FROM scrap_records WHERE id = ?`,
      [result.insertId]
    );

    res.json({
      success: true,
      data: inserted[0],
    });
  } catch (err) {
    next(err);
  }
};

// ============================================
// GET /api/scrap/records
// Historial de scrap por rango de fecha
// ============================================
exports.getRecords = async (req, res, next) => {
  try {
    const { fecha_inicio, fecha_fin, area, limit } = req.query;

    if (!fecha_inicio || !fecha_fin) {
      return res.status(400).json({
        success: false,
        message: 'fecha_inicio y fecha_fin son requeridos',
      });
    }

    const maxRows = parseInt(limit) || 5000;

    let query = `
      SELECT s.*, 
             DATE_FORMAT(s.fecha_registro, '%Y-%m-%d') as fecha, 
             DATE_FORMAT(s.fecha_registro, '%H:%i:%s') as hora
      FROM scrap_records s
      WHERE DATE(s.fecha_registro) BETWEEN ? AND ?
    `;
    const params = [fecha_inicio, fecha_fin];

    if (area && VALID_AREAS.includes(area)) {
      query += ` AND s.area = ?`;
      params.push(area);
    }

    query += ` ORDER BY s.fecha_registro DESC LIMIT ?`;
    params.push(maxRows);

    const [rows] = await pool.query(query, params);

    res.json({
      success: true,
      data: rows,
      count: rows.length,
    });
  } catch (err) {
    next(err);
  }
};

// ============================================
// DELETE /api/scrap/record/:id
// Elimina un registro de scrap (para deshacer)
// ============================================
exports.deleteRecord = async (req, res, next) => {
  try {
    const { id } = req.params;

    const [result] = await pool.query(
      `DELETE FROM scrap_records WHERE id = ?`,
      [id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Registro no encontrado',
      });
    }

    res.json({ success: true });
  } catch (err) {
    next(err);
  }
};

// ============================================
// GET /api/scrap/autocomplete?q=xxx&area=yyy
// Busca PCBs en tabla raw o componentes en tabla materiales
// ============================================
exports.autocomplete = async (req, res, next) => {
  try {
    const { q, area } = req.query;

    if (!q || q.trim().length < 3) {
      return res.json({ success: true, data: [] });
    }

    const searchTerm = `%${q.trim()}%`;

    if (area === 'COMPONENTE') {
      // Buscar en tabla materiales por numero_parte o especificacion
      const [rows] = await pool.query(
        `SELECT DISTINCT 
           numero_parte as part_no, 
           codigo_material as model, 
           especificacion_material as project 
         FROM materiales 
         WHERE (numero_parte LIKE ? OR especificacion_material LIKE ?)
           AND numero_parte IS NOT NULL AND numero_parte != ''
         ORDER BY numero_parte
         LIMIT 20`,
        [searchTerm, searchTerm]
      );
      return res.json({ success: true, data: rows });
    } else {
      // Búsqueda por defecto en tabla raw para PCBs
      const [rows] = await pool.query(
        `SELECT DISTINCT part_no, model, project 
         FROM raw 
         WHERE part_no LIKE ? AND part_no IS NOT NULL AND part_no != ''
         ORDER BY part_no
         LIMIT 20`,
        [searchTerm]
      );
      return res.json({ success: true, data: rows });
    }
  } catch (err) {
    next(err);
  }
};
