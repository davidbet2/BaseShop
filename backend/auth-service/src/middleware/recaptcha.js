const axios = require('axios');
const RECAPTCHA_THRESHOLD = parseFloat(process.env.RECAPTCHA_THRESHOLD || '0.5');

const verifyRecaptcha = async (req, res, next) => {
  const userAgent = req.headers['user-agent'] || '';
  const xPlatform = req.headers['x-platform'] || '';

  // 1) Detectar cliente móvil — SIEMPRE saltar reCAPTCHA
  const isMobile = xPlatform.toLowerCase() === 'mobile' ||
    userAgent.includes('Dart') ||
    userAgent.includes('okhttp') ||
    userAgent.includes('Flutter') ||
    (!userAgent.includes('Mozilla') && !userAgent.includes('Chrome') && !userAgent.includes('Safari'));

  if (isMobile) {
    console.log('[reCAPTCHA] ✅ Mobile client detected, skipping');
    return next();
  }

  // 2) Sin secret key → dev mode, saltar
  const recaptchaSecret = process.env.RECAPTCHA_SECRET_KEY || '';
  if (!recaptchaSecret) {
    console.warn('[reCAPTCHA] ⚠️ No RECAPTCHA_SECRET_KEY, skipping (dev mode)');
    return next();
  }

  // 3) Web client — verificar con Google
  const recaptchaToken = req.body.recaptchaToken || req.headers['x-recaptcha-token'];
  if (!recaptchaToken) {
    return res.status(400).json({ error: 'Token de reCAPTCHA requerido' });
  }

  try {
    const response = await axios.post(
      'https://www.google.com/recaptcha/api/siteverify', null,
      { params: { secret: recaptchaSecret, response: recaptchaToken, remoteip: req.ip }, timeout: 5000 }
    );
    const { success, score } = response.data;

    if (!success) {
      return res.status(403).json({ error: 'Verificación de reCAPTCHA fallida' });
    }
    if (score !== undefined && score < RECAPTCHA_THRESHOLD) {
      return res.status(403).json({ error: 'Actividad sospechosa detectada. Intenta de nuevo.' });
    }

    req.recaptchaScore = score;
    next();
  } catch (error) {
    // M4 fix: log warning but still allow (with a warning flag for rate-limiting)
    console.warn('[reCAPTCHA] ⚠️  Google verification failed (network error):', error.message);
    req.recaptchaBypass = true; // flag for downstream rate-limiting
    next();
  }
};

module.exports = { verifyRecaptcha };
