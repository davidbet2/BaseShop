const axios = require('axios');
const RECAPTCHA_THRESHOLD = parseFloat(process.env.RECAPTCHA_THRESHOLD || '0.5');

const verifyRecaptcha = async (req, res, next) => {
  // 1) Check for mobile app signature (for native mobile clients that can't use reCAPTCHA)
  const appSignature = req.headers['x-app-signature'];
  const mobileAppSecret = process.env.MOBILE_APP_SECRET;

  if (appSignature && mobileAppSecret && appSignature === mobileAppSecret) {
    req.recaptchaVerified = true;
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
    console.error('[reCAPTCHA] Google verification failed (network error):', error.message);
    return res.status(503).json({
      success: false,
      message: 'Verificación de seguridad temporalmente no disponible. Intenta de nuevo.'
    });
  }
};

module.exports = { verifyRecaptcha };
