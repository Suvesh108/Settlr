import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useUIStore } from '../../store/uiStore';
import { Expense, Group, GroupMember, Settlement } from '../../types';
import { formatMoney, formatDate } from '../../utils/formatters';
import { AnimatedModal } from '../ui/AnimatedModal';
import { 
  Download, 
  FileSpreadsheet, 
  FileCode, 
  Printer, 
  X, 
  Check, 
  Receipt,
  FileCheck2
} from 'lucide-react';

interface ExportLedgerModalProps {
  group: Group;
  expenses: Expense[];
  settlements: Settlement[];
  members: GroupMember[];
}

export const ExportLedgerModal: React.FC<ExportLedgerModalProps> = ({
  group,
  expenses = [],
  settlements = [],
  members = [],
}) => {
  const { isExportLedgerOpen, setIsExportLedgerOpen } = useUIStore();
  const [downloadSuccess, setDownloadSuccess] = useState<string | null>(null);

  if (!isExportLedgerOpen) return null;

  const activeExpenses = expenses.filter((e) => !e.is_reversed && !e.is_reversal);

  const getMemberName = (id: string) => {
    return members.find((m) => m.user_id === id)?.name || 'Member';
  };

  // 1. Generate CSV with UTF-8 BOM for Microsoft Excel & Google Sheets
  const handleExportCSV = () => {
    const headers = [
      'Transaction ID',
      'Date',
      'Description',
      'Category',
      'Paid By',
      'Amount (Minor Units)',
      `Amount (${group.currency})`,
      'Split Type',
      'Status',
      'Participants & Shares',
    ];

    const rows = activeExpenses.map((e) => {
      const payerName = getMemberName(e.paid_by);
      const formattedAmt = (e.amount / 100).toFixed(2);
      const dateStr = formatDate(e.created_at || e.expense_date);
      const participantShares = (e.participants || [])
        .map((p) => `${getMemberName(p.user_id)}: ${(p.share_amount / 100).toFixed(2)}`)
        .join('; ');

      return [
        `"${e.id}"`,
        `"${dateStr}"`,
        `"${e.description.replace(/"/g, '""')}"`,
        `"${e.category}"`,
        `"${payerName.replace(/"/g, '""')}"`,
        e.amount,
        formattedAmt,
        `"${e.split_type}"`,
        `"ACTIVE"`,
        `"${participantShares.replace(/"/g, '""')}"`,
      ].join(',');
    });

    const csvContent = '\uFEFF' + [headers.join(','), ...rows].join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Settlr_Ledger_${group.name.replace(/\s+/g, '_')}_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    URL.revokeObjectURL(url);

    setDownloadSuccess('CSV Export downloaded successfully!');
    setTimeout(() => setDownloadSuccess(null), 3000);
  };

  // 2. Generate JSON Archive
  const handleExportJSON = () => {
    const archiveData = {
      group: {
        id: group.id,
        name: group.name,
        currency: group.currency,
        created_at: group.created_at,
        exported_at: new Date().toISOString(),
      },
      members: members.map((m) => ({ id: m.user_id, name: m.name, role: m.role })),
      expenses: activeExpenses.map((e) => ({
        id: e.id,
        description: e.description,
        amount: e.amount,
        category: e.category,
        paid_by: e.paid_by,
        payer_name: getMemberName(e.paid_by),
        date: e.created_at || e.expense_date,
        split_type: e.split_type,
        participants: e.participants,
      })),
      settlements: settlements.map((s) => ({
        id: s.id,
        from_user: s.from_user,
        from_name: getMemberName(s.from_user),
        to_user: s.to_user,
        to_name: getMemberName(s.to_user),
        amount: s.amount,
        status: s.status,
        date: s.created_at,
      })),
    };

    const blob = new Blob([JSON.stringify(archiveData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Settlr_Archive_${group.name.replace(/\s+/g, '_')}_${new Date().toISOString().split('T')[0]}.json`;
    link.click();
    URL.revokeObjectURL(url);

    setDownloadSuccess('JSON Archive exported successfully!');
    setTimeout(() => setDownloadSuccess(null), 3000);
  };

  // 3. Print Ledger
  const handlePrint = () => {
    window.print();
  };

  return (
    <AnimatedModal
      isOpen={isExportLedgerOpen}
      onClose={() => setIsExportLedgerOpen(false)}
      maxWidth="max-w-2xl"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-neutral-900 text-white flex items-center justify-center shadow-2xs">
            <Download className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-bold text-base text-neutral-900">Export & Audit Ledger</h3>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 uppercase tracking-wider">
                Settle Up Premium
              </span>
            </div>
            <p className="text-xs text-neutral-500">
              Download clean spreadsheets, complete JSON backup, or print audit report
            </p>
          </div>
        </div>
        <motion.button
          whileHover={{ scale: 1.1, rotate: 90 }}
          whileTap={{ scale: 0.9 }}
          onClick={() => setIsExportLedgerOpen(false)}
          className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
        >
          <X className="w-4 h-4" />
        </motion.button>
      </div>

      {downloadSuccess && (
        <div className="mt-4 p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs flex items-center gap-2 font-medium">
          <Check className="w-4 h-4 shrink-0" />
          <span>{downloadSuccess}</span>
        </div>
      )}

      {/* Export Format Buttons */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-5">
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="button"
          onClick={handleExportCSV}
          className="p-4 rounded-xl border border-neutral-200 bg-white hover:bg-neutral-50 hover:border-neutral-300 text-left transition-all cursor-pointer shadow-2xs group"
        >
          <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center mb-2.5 group-hover:scale-105 transition-transform">
            <FileSpreadsheet className="w-4 h-4" />
          </div>
          <span className="text-xs font-bold text-neutral-900 block">Export as CSV</span>
          <span className="text-[10px] text-neutral-500 mt-0.5 block leading-relaxed">
            Formatted for Excel, Google Sheets, & Numbers with full split breakdown.
          </span>
        </motion.button>

        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="button"
          onClick={handleExportJSON}
          className="p-4 rounded-xl border border-neutral-200 bg-white hover:bg-neutral-50 hover:border-neutral-300 text-left transition-all cursor-pointer shadow-2xs group"
        >
          <div className="w-8 h-8 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center mb-2.5 group-hover:scale-105 transition-transform">
            <FileCode className="w-4 h-4" />
          </div>
          <span className="text-xs font-bold text-neutral-900 block">JSON Vault Archive</span>
          <span className="text-[10px] text-neutral-500 mt-0.5 block leading-relaxed">
            Complete database snapshot with transactions, shares, and settlements.
          </span>
        </motion.button>

        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="button"
          onClick={handlePrint}
          className="p-4 rounded-xl border border-neutral-200 bg-white hover:bg-neutral-50 hover:border-neutral-300 text-left transition-all cursor-pointer shadow-2xs group"
        >
          <div className="w-8 h-8 rounded-lg bg-neutral-100 text-neutral-700 flex items-center justify-center mb-2.5 group-hover:scale-105 transition-transform">
            <Printer className="w-4 h-4" />
          </div>
          <span className="text-xs font-bold text-neutral-900 block">Print Audit Ledger</span>
          <span className="text-[10px] text-neutral-500 mt-0.5 block leading-relaxed">
            Print-ready clean accounting document for physical filing or PDF save.
          </span>
        </motion.button>
      </div>

      {/* Preview Table */}
      <div className="mt-6">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
            Ledger Records Preview ({activeExpenses.length} entries)
          </span>
          <span className="text-[11px] text-neutral-400">
            Group: {group.name} ({group.currency})
          </span>
        </div>

        <div className="border border-neutral-200 rounded-xl overflow-hidden max-h-56 overflow-y-auto">
          <table className="w-full text-left text-[11px]">
            <thead className="bg-neutral-50 text-neutral-600 border-b border-neutral-200 font-semibold sticky top-0">
              <tr>
                <th className="py-2 px-3">Date</th>
                <th className="py-2 px-3">Description</th>
                <th className="py-2 px-3">Category</th>
                <th className="py-2 px-3">Payer</th>
                <th className="py-2 px-3 text-right">Amount</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100 bg-white">
              {activeExpenses.slice(0, 15).map((e) => (
                <tr key={e.id} className="hover:bg-neutral-50/70 transition-colors">
                  <td className="py-2 px-3 text-neutral-500 whitespace-nowrap">
                    {formatDate(e.created_at || e.expense_date)}
                  </td>
                  <td className="py-2 px-3 font-semibold text-neutral-900 max-w-[140px] truncate">
                    {e.description}
                  </td>
                  <td className="py-2 px-3">
                    <span className="px-1.5 py-0.5 rounded text-[10px] font-semibold bg-neutral-100 text-neutral-700">
                      {e.category}
                    </span>
                  </td>
                  <td className="py-2 px-3 text-neutral-600 whitespace-nowrap">
                    {getMemberName(e.paid_by)}
                  </td>
                  <td className="py-2 px-3 text-right font-extrabold text-neutral-900 num-tabular whitespace-nowrap">
                    {formatMoney(e.amount, group.currency)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 flex items-center justify-end border-t border-neutral-100 pt-4">
        <button
          type="button"
          onClick={() => setIsExportLedgerOpen(false)}
          className="px-4 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold shadow-2xs transition-all cursor-pointer"
        >
          Close
        </button>
      </div>
    </AnimatedModal>
  );
};
