// ══════════════════════════════════════════════════════════
// Brevo SMTP Email Service (via nodemailer)
// Envía emails transaccionales: verificación y recuperación
// ══════════════════════════════════════════════════════════
const nodemailer = require('nodemailer');

const SMTP_HOST = process.env.BREVO_SMTP_HOST || 'smtp-relay.brevo.com';
const SMTP_PORT = parseInt(process.env.BREVO_SMTP_PORT || '587', 10);
const SMTP_USER = process.env.BREVO_SMTP_USER || '';
const SMTP_PASS = process.env.BREVO_SMTP_PASS || '';
const SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'shopbrevosmtp@gmail.com';
const SENDER_NAME = process.env.BREVO_SENDER_NAME || 'BaseShop';

let transporter = null;

function getTransporter() {
  if (!transporter) {
    if (!SMTP_USER || !SMTP_PASS) {
      console.warn('[Brevo] ⚠️  SMTP credentials not set — emails will be logged to console (dev mode)');
      return null;
    }
    transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: false, // STARTTLS
      auth: { user: SMTP_USER, pass: SMTP_PASS },
      tls: { rejectUnauthorized: false },
    });
    console.log(`[Brevo] SMTP transport ready → ${SMTP_HOST}:${SMTP_PORT}`);
  }
  return transporter;
}

/**
 * Genera un código numérico de 6 dígitos
 */
function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Envía un email genérico vía SMTP
 */
async function sendMail(to, toName, subject, htmlContent) {
  let smtp;
  try { smtp = getTransporter(); } catch (err) {
    console.error('[Brevo] Transport error:', err.message);
    smtp = null;
  }

  if (!smtp) {
    console.log(`[Brevo-DEV] 📧 ${subject} → ${to}`);
    return true;
  }

  try {
    const info = await smtp.sendMail({
      from: `"${SENDER_NAME}" <${SENDER_EMAIL}>`,
      to: toName ? `"${toName}" <${to}>` : to,
      subject,
      html: htmlContent,
    });
    console.log(`[Brevo] ✅ Email sent to ${to} (messageId: ${info.messageId})`);
    return true;
  } catch (error) {
    console.error('[Brevo] ❌ Error sending email:', error.message || error);
    return false;
  }
}

/**
 * Envía email de verificación de cuenta
 */
async function sendVerificationEmail(toEmail, toName, code) {
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
  return sendMail(toEmail, toName, `${SENDER_NAME} — Código de verificación: ${code}`, htmlContent);
}

/**
 * Envía email de recuperación de contraseña
 */
async function sendPasswordResetEmail(toEmail, toName, code) {
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
  return sendMail(toEmail, toName, `${SENDER_NAME} — Código de recuperación: ${code}`, htmlContent);
}

module.exports = { generateCode, sendVerificationEmail, sendPasswordResetEmail };
