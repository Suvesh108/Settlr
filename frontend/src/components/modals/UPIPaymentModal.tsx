import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { useUIStore } from '../../store/uiStore';
import { useAuthStore } from '../../store/authStore';
import { formatMoney } from '../../utils/formatters';
import { apiRequest } from '../../services/api';
import { useQueryClient } from '@tanstack/react-query';
import { AnimatedModal } from '../ui/AnimatedModal';
import QRCode from 'qrcode';
import { 
  QrCode, 
  X, 
  Check, 
  ExternalLink, 
  AlertCircle, 
  Copy, 
  Smartphone,
  ShieldCheck,
  Edit2
} from 'lucide-react';

interface UPIPaymentModalProps {
  groupId: string;
  currency: string;
}

export const UPIPaymentModal: React.FC<UPIPaymentModalProps> = ({
  groupId,
  currency,
}) => {
  const { isUPIPaymentOpen, setIsUPIPaymentOpen, upiPaymentDetails } = useUIStore();
  const currentUserId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();

  const [qrDataUrl, setQrDataUrl] = useState<string>('');
  const [upiId, setUpiId] = useState<string>('');
  const [isEditingUpi, setIsEditingUpi] = useState<boolean>(false);
  const [copied, setCopied] = useState<boolean>(false);
  const [recording, setRecording] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const toUserId = upiPaymentDetails?.toUserId || '';
  const toUserName = upiPaymentDetails?.toUserName || 'Member';
  const amountPaise = upiPaymentDetails?.amount || 0;
  const amountRupees = (amountPaise / 100).toFixed(2);

  // Initialize or fetch saved UPI ID
  useEffect(() => {
    if (toUserId) {
      const saved = localStorage.getItem(`settlr_upi_${toUserId}`);
      if (saved) {
        setUpiId(saved);
      } else {
        const defaultUpi = `${toUserName.toLowerCase().replace(/[^a-z0-9]/g, '')}@okaxis`;
        setUpiId(defaultUpi);
      }
    }
  }, [toUserId, toUserName]);

  // Generate QR code whenever UPI ID or amount changes
  useEffect(() => {
    if (!upiId || amountPaise <= 0) return;

    const upiUri = `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(toUserName)}&am=${amountRupees}&cu=INR&tn=${encodeURIComponent('Settlr Settlement')}`;

    QRCode.toDataURL(upiUri, {
      width: 260,
      margin: 1.5,
      color: {
        dark: '#171717',
        light: '#ffffff',
      },
      errorCorrectionLevel: 'M',
    })
      .then((url) => setQrDataUrl(url))
      .catch((err) => console.error('QR code generation failed:', err));
  }, [upiId, toUserName, amountRupees, amountPaise]);

  if (!isUPIPaymentOpen) return null;

  const handleSaveUpiId = (newId: string) => {
    const clean = newId.trim();
    setUpiId(clean);
    if (toUserId && clean) {
      localStorage.setItem(`settlr_upi_${toUserId}`, clean);
    }
    setIsEditingUpi(false);
  };

  const handleCopyUpiUri = () => {
    const upiUri = `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(toUserName)}&am=${amountRupees}&cu=INR&tn=${encodeURIComponent('Settlr Settlement')}`;
    navigator.clipboard.writeText(upiUri);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleRecordPayment = async () => {
    setError(null);
    setRecording(true);
    try {
      await apiRequest(`/groups/${groupId}/settlements`, {
        method: 'POST',
        useIdempotency: true,
        body: JSON.stringify({
          to_user: toUserId,
          amount: amountPaise,
        }),
      });

      queryClient.invalidateQueries({ queryKey: ['group', groupId] });
      queryClient.invalidateQueries({ queryKey: ['balances', groupId] });
      queryClient.invalidateQueries({ queryKey: ['pairwise', groupId] });
      queryClient.invalidateQueries({ queryKey: ['settlements', groupId] });
      queryClient.invalidateQueries({ queryKey: ['recommended', groupId] });
      queryClient.invalidateQueries({ queryKey: ['activity', groupId] });

      setIsUPIPaymentOpen(false);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to record settlement');
    } finally {
      setRecording(false);
    }
  };

  const directUpiLink = `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(toUserName)}&am=${amountRupees}&cu=INR&tn=${encodeURIComponent('Settlr Settlement')}`;

  return (
    <AnimatedModal
      isOpen={isUPIPaymentOpen}
      onClose={() => setIsUPIPaymentOpen(false)}
      maxWidth="max-w-md"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-emerald-600 text-white flex items-center justify-center shadow-2xs">
            <QrCode className="w-4 h-4" />
          </div>
          <div>
            <h3 className="font-bold text-base text-neutral-900">Scan to Pay via UPI</h3>
            <p className="text-xs text-neutral-500">Pay directly with Google Pay, PhonePe, or Paytm</p>
          </div>
        </div>
        <motion.button
          whileHover={{ scale: 1.1, rotate: 90 }}
          whileTap={{ scale: 0.9 }}
          onClick={() => setIsUPIPaymentOpen(false)}
          className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
        >
          <X className="w-4 h-4" />
        </motion.button>
      </div>

      {error && (
        <div className="mt-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2 font-medium">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Payee Info & Amount Badge */}
      <div className="mt-4 p-4 rounded-2xl bg-neutral-50 border border-neutral-200/70 text-center">
        <span className="text-xs font-semibold text-neutral-500 block">Total Due to Settle</span>
        <div className="text-3xl font-extrabold text-neutral-900 num-tabular tracking-tight my-1">
          {formatMoney(amountPaise, currency)}
        </div>
        <div className="text-xs font-medium text-neutral-700 flex items-center justify-center gap-1.5 mt-1">
          <span>Recipient:</span>
          <span className="font-bold text-neutral-900">{toUserName}</span>
        </div>

        {/* Recipient UPI ID with Edit Capability */}
        <div className="mt-2.5 pt-2.5 border-t border-neutral-200/60 flex items-center justify-center gap-1.5">
          {isEditingUpi ? (
            <div className="flex items-center gap-1.5 w-full max-w-xs">
              <input
                type="text"
                value={upiId}
                onChange={(e) => setUpiId(e.target.value)}
                placeholder="e.g. mobile@paytm or name@okhdfcbank"
                className="flex-1 px-2.5 py-1 rounded-md text-xs font-mono border border-neutral-300 focus:outline-none focus:border-neutral-900 bg-white"
              />
              <button
                type="button"
                onClick={() => handleSaveUpiId(upiId)}
                className="px-2.5 py-1 rounded-md bg-neutral-900 text-white text-xs font-semibold cursor-pointer"
              >
                Save
              </button>
            </div>
          ) : (
            <div className="flex items-center gap-2">
              <span className="text-[11px] font-mono text-neutral-600 bg-white px-2 py-0.5 rounded border border-neutral-200">
                {upiId}
              </span>
              <button
                type="button"
                onClick={() => setIsEditingUpi(true)}
                title="Edit recipient UPI ID"
                className="text-neutral-400 hover:text-neutral-700 p-1"
              >
                <Edit2 className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* QR Code Container */}
      <div className="my-5 flex flex-col items-center justify-center">
        <div className="p-3 rounded-2xl bg-white border border-neutral-200 shadow-sm inline-block">
          {qrDataUrl ? (
            <img src={qrDataUrl} alt="UPI Payment QR Code" className="w-52 h-52 object-contain rounded-lg" />
          ) : (
            <div className="w-52 h-52 flex items-center justify-center bg-neutral-50 rounded-lg text-neutral-400 text-xs">
              Generating QR Code...
            </div>
          )}
        </div>
        <span className="text-[11px] font-medium text-neutral-500 mt-2.5 flex items-center gap-1">
          <Smartphone className="w-3 h-3 text-emerald-600" />
          <span>Scan with any banking app (GPay, PhonePe, Paytm, BHIM)</span>
        </span>
      </div>

      {/* Direct App Link for Mobile & Copy Link */}
      <div className="flex flex-col sm:flex-row gap-2">
        <a
          href={directUpiLink}
          className="flex-1 inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-neutral-100 hover:bg-neutral-200/80 text-neutral-800 text-xs font-semibold transition-all shadow-2xs text-center"
        >
          <ExternalLink className="w-3.5 h-3.5" />
          <span>Open in UPI App</span>
        </a>

        <button
          type="button"
          onClick={handleCopyUpiUri}
          className="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-white hover:bg-neutral-50 border border-neutral-200 text-neutral-700 text-xs font-semibold transition-all shadow-2xs cursor-pointer"
        >
          {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5 text-neutral-400" />}
          <span>{copied ? 'Copied URI' : 'Copy Pay Link'}</span>
        </button>
      </div>

      {/* Confirmation of Payment */}
      <div className="mt-5 border-t border-neutral-100 pt-4 flex items-center justify-between gap-3">
        <div className="text-[11px] text-neutral-400 leading-tight">
          Already paid via UPI?
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="button"
          disabled={recording}
          onClick={handleRecordPayment}
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold shadow-sm transition-all cursor-pointer disabled:opacity-50"
        >
          <Check className="w-3.5 h-3.5" />
          <span>{recording ? 'Recording...' : 'Mark as Paid in Settlr'}</span>
        </motion.button>
      </div>
    </AnimatedModal>
  );
};
