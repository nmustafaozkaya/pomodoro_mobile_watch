const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 4001;
const DB_PATH = path.join(__dirname, 'pomodoro.db');

// Middleware
app.use(cors());
app.use(express.json());

// SQLite veritabanı bağlantısı
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('Veritabani baglanti hatasi:', err.message);
  } else {
    console.log('SQLite veritabanina baglandi');
    // Sessions tablosunu oluştur
    db.run(`CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId TEXT NOT NULL,
      source TEXT NOT NULL,
      minutes INTEGER NOT NULL,
      ts INTEGER NOT NULL,
      createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Tablo olusturma hatasi:', err.message);
      } else {
        console.log('Sessions tablosu hazir');
      }
    });
  }
});

// POST /api/session - Yeni session kaydet
app.post('/api/session', (req, res) => {
  const { userId, source, minutes, ts } = req.body;

  // Validasyon
  if (!userId || !source || minutes === undefined || !ts) {
    return res.status(400).json({ error: 'Eksik parametreler' });
  }

  const sql = `INSERT INTO sessions (userId, source, minutes, ts) VALUES (?, ?, ?, ?)`;
  
  db.run(sql, [userId, source, minutes, ts], function(err) {
    if (err) {
      console.error('Session kayit hatasi:', err.message);
      return res.status(500).json({ error: 'Session kaydedilemedi' });
    }
    
    res.status(200).json({ 
      success: true, 
      id: this.lastID,
      message: 'Session kaydedildi' 
    });
  });
});

// GET /api/stats - İstatistikleri getir
app.get('/api/stats', (req, res) => {
  const userId = req.query.userId;

  if (!userId) {
    return res.status(400).json({ error: 'userId parametresi gerekli' });
  }

  // Toplam dakikayı hesapla
  const totalSql = `SELECT SUM(minutes) as totalMinutes FROM sessions WHERE userId = ?`;
  
  db.get(totalSql, [userId], (err, totalRow) => {
    if (err) {
      console.error('Toplam dakika hesaplama hatasi:', err.message);
      return res.status(500).json({ error: 'İstatistikler alınamadı' });
    }

    const totalMinutes = totalRow?.totalMinutes || 0;

    // Son 30 günün sessionlarını getir (recent için)
    const recentSql = `SELECT minutes, ts, source FROM sessions 
                      WHERE userId = ? 
                      ORDER BY ts DESC 
                      LIMIT 100`;
    
    db.all(recentSql, [userId], (err, sessions) => {
      if (err) {
        console.error('Session listeleme hatasi:', err.message);
        return res.status(500).json({ error: 'Sessionlar alınamadı' });
      }

      const recent = sessions.map(session => ({
        minutes: session.minutes,
        ts: session.ts,
        source: session.source || 'unknown' // Source ekle
      }));

      res.json({
        totalMinutes: totalMinutes,
        recent: recent
      });
    });
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// Sunucuyu başlat - TÜM network interface'lerde dinle
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Pomodoro API ${PORT} portunda calisiyor`);
  console.log(`Local: http://localhost:${PORT}/health`);
  console.log(`Network: http://0.0.0.0:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  db.close((err) => {
    if (err) {
      console.error('Veritabani kapatma hatasi:', err.message);
    } else {
      console.log('Veritabani baglantisi kapatildi');
    }
    process.exit(0);
  });
});

