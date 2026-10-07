import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class IslandHeader extends StatefulWidget {
  final int currentMode; // 0: Groups, 1: Personal
  final ValueChanged<int> onModeChanged;
  final List<Group> groups;
  final Group? activeGroup;
  final ValueChanged<Group> onSelectGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  final VoidCallback onOpenProfile;
  final String userName;
  final String currentUserId;

  const IslandHeader({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.groups,
    required this.activeGroup,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onJoinGroup,
    required this.onOpenProfile,
    required this.userName,
    required this.currentUserId,
  });

  @override
  State<IslandHeader> createState() => _IslandHeaderState();
}

class _IslandHeaderState extends State<IslandHeader> {
  bool _copied = false;

  void _copyInviteCode() {
    if (widget.activeGroup?.invite_code != null && widget.activeGroup!.invite_code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: widget.activeGroup!.invite_code));
      HapticFeedback.mediumImpact();
      setState(() => _copied = true);
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  void _showGroupPicker(BuildContext context) {
    if (widget.groups.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Active Ledger',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: SettlrColors.textMain,
                        ),
                      ),
                      BouncyPress(
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onCreateGroup();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: SettlrColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.groups.length,
                    itemBuilder: (ctx, i) {
                      final g = widget.groups[i];
                      final isSelected = widget.activeGroup?.id == g.id;
                      return ListTile(
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onSelectGroup(g);
                        },
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? SettlrColors.primary : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              g.name.isNotEmpty ? g.name.substring(0, 1).toUpperCase() : 'G',
                              style: TextStyle(
                                color: isSelected ? Colors.white : SettlrColors.textMain,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          g.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: SettlrColors.textMain,
                          ),
                        ),
                        subtitle: Text(
                          '${g.currency} · ${g.members?.length ?? 0} members',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: SettlrColors.positive, size: 20)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.isNotEmpty
        ? widget.userName.substring(0, widget.userName.length >= 2 ? 2 : 1).toUpperCase()
        : 'U';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          // Row 1: Brand Logo, Segmented Control (Personal vs Groups), Profile Avatar
          Row(
            children: [
              // Brand Icon
              Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(width: 8),

              // Segmented Switch: Personal | Groups
              Expanded(
                child: SlidingPillSegment(
                  selectedIndex: widget.currentMode,
                  itemCount: 2,
                  height: 34,
                  onSelected: widget.onModeChanged,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 15,
                          color: widget.currentMode == 0 ? SettlrColors.primary : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Groups',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: widget.currentMode == 0 ? FontWeight.bold : FontWeight.w500,
                            color: widget.currentMode == 0 ? SettlrColors.primary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 15,
                          color: widget.currentMode == 1 ? SettlrColors.primary : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Personal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: widget.currentMode == 1 ? FontWeight.bold : FontWeight.w500,
                            color: widget.currentMode == 1 ? SettlrColors.primary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Profile Avatar Pill
              BouncyPress(
                onTap: widget.onOpenProfile,
                scaleDown: 0.92,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SettlrColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Row 2 (When in Groups mode and groups exist): Active Group Chip & Actions
          if (widget.currentMode == 0 && widget.groups.isNotEmpty && widget.activeGroup != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Group selector pill
                Expanded(
                  child: BouncyPress(
                    onTap: () => _showGroupPicker(context),
                    scaleDown: 0.97,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.activeGroup!.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: SettlrColors.textMain,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Share / Invite code button if group creator
                if (widget.activeGroup!.invite_code.isNotEmpty &&
                    widget.activeGroup!.created_by == widget.currentUserId)
                  BouncyPress(
                    onTap: _copyInviteCode,
                    scaleDown: 0.92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _copied ? SettlrColors.positiveBg : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _copied ? SettlrColors.positive : const Color(0x1A000000),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _copied ? Icons.check : Icons.copy,
                            size: 13,
                            color: _copied ? SettlrColors.positive : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.activeGroup!.invite_code,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _copied ? SettlrColors.positive : SettlrColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(width: 4),

                // Join Group button
                BouncyPress(
                  onTap: widget.onJoinGroup,
                  scaleDown: 0.90,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.group_add_outlined, size: 16, color: SettlrColors.textMain),
                  ),
                ),

                const SizedBox(width: 4),

                // Create Group button
                BouncyPress(
                  onTap: widget.onCreateGroup,
                  scaleDown: 0.90,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: SettlrColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
