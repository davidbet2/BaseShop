// ══════════════════════════════════════════════════════════
// Brevo (Sendinblue) Email Service
// Envía emails transaccionales: verificación y recuperación
// ══════════════════════════════════════════════════════════
const SibApiV3Sdk = require('sib-api-v3-sdk');

const BREVO_API_KEY = process.env.BREVO_API_KEY || '';
const SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'shopbrevosmtp@gmail.com';
const SENDER_NAME = process.env.BREVO_SENDER_NAME || 'BaseShop';

let apiInstance = null;

function getApi() {
  if (!apiInstance) {
    if (!BREVO_API_KEY) {
      console.warn('[Brevo] ⚠️  BREVO_API_KEY not set — emails will be logged to console (dev mode)');
      return null;
    }
    const defaultClient = SibApiV3Sdk.ApiClient.instance;
    const apiKey = defaultClient.authentications['api-key'];
    apiKey.apiKey = BREVO_API_KEY;
    apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();
  }
  return apiInstance;
}

/**
 * Genera un código numérico de 6 dígitos
 */
function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Envía email de verificación de cuenta
 */
async function sendVerificationEmail(toEmail, toName, code) {
  let api;
  try { api = getApi(); } catch (err) {
    console.error('[Brevo] getApi error:', err.message);
    api = null;
  }

  const htmlContent = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; background: #ffffff;">
      <div style="text-align: center; margin-bottom: 32px;">
        <h1 style="font-size: 24px; font-weight: 700; color: #1a1a2e; margin: 0;">Verifica tu cuenta</h1>
        <p style="font-size: 15px; color: #6b7280; margin-top: 8px;">¡Hola${toName ? ` ${toName}` : ''}! Usa este código para verificar tu cuenta.</p>
      </div>
      <div style="text-align: center; background: #f3f4f6; border-radius: 16px; padding: 28px 16px; margin-bottom: 24px;">
        <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #1a1a2e; font-family: 'Courier New', monospace;">${code}</span>
      </div>
      <p style="font-size: 13px; color: #9ca3af; text-align: center;">Este código expira en <strong>30 minutos</strong>.</p>
      <p style="font-size: 13px; color: #9ca3af; text-align: center;">Si no creaste esta cuenta, ignora este mensaje.</p>
      <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
      <p style="font-size: 12px; color: #d1d5db; text-align: center;">${SENDER_NAME}</p>
    </div>
  `;

  if (!api) {
    console.log(`[Brevo-DEV] 📧 Verification email to ${toEmail} — code: ${code}`);
    return true;
  }

  try {
    const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
    sendSmtpEmail.subject = `${SENDER_NAME} — Código de verificación: ${code}`;
    sendSmtpEmail.htmlContent = htmlContent;
    sendSmtpEmail.sender = { name: SENDER_NAME, email: SENDER_EMAIL };
    sendSmtpEmail.to = [{ email: toEmail, name: toName || '' }];

    await api.sendTransacEmail(sendSmtpEmail);
    console.log(`[Brevo] ✅ Verification email sent to ${toEmail}`);
    return true;
  } catch (error) {
    console.error('[Brevo] ❌ Error sending verification email:', error.message || error);
    return false;
  }
}

/**
 * Envía email de recuperación de contraseña
 */
async function sendPasswordResetEmail(toEmail, toName, code) {
  let api;
  try { api = getApi(); } catch (err) {
    console.error('[Brevo] getApi error:', err.message);
    api = null;
  }

  const htmlContent = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; background: #ffffff;">
      <div style="text-align: center; margin-bottom: 32px;">
        <h1 style="font-size: 24px; font-weight: 700; color: #1a1a2e; margin: 0;">Recuperar contraseña</h1>
        <p style="font-size: 15px; color: #6b7280; margin-top: 8px;">Usa este código para restablecer tu contraseña.</p>
      </div>
      <div style="text-align: center; background: #f3f4f6; border-radius: 16px; padding: 28px 16px; margin-bottom: 24px;">
        <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #1a1a2e; font-family: 'Courier New', monospace;">${code}</span>
      </div>
      <p style="font-size: 13px; color: #9ca3af; text-align: center;">Este código expira en <strong>30 minutos</strong>.</p>
      <p style="font-size: 13px; color: #9ca3af; text-align: center;">Si no solicitaste este cambio, ignora este mensaje.</p>
      <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
      <p style="font-size: 12px; color: #d1d5db; text-align: center;">${SENDER_NAME}</p>
    </div>
  `;

  if (!api) {
    console.log(`[Brevo-DEV] 📧 Password reset email to ${toEmail} — code: ${code}`);
    return true;
  }

  try {
    const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
    sendSmtpEmail.subject = `${SENDER_NAME} — Código de recuperación: ${code}`;
    sendSmtpEmail.htmlContent = htmlContent;
    sendSmtpEmail.sender = { name: SENDER_NAME, email: SENDER_EMAIL };
    sendSmtpEmail.to = [{ email: toEmail, name: toName || '' }];

    await api.sendTransacEmail(sendSmtpEmail);
    console.log(`[Brevo] ✅ Password reset email sent to ${toEmail}`);
    return true;
  } catch (error) {
    console.error('[Brevo] ❌ Error sending password reset email:', error.message || error);
    return false;
  }
}

module.exports = { generateCode, sendVerificationEmail, sendPasswordResetEmail };
