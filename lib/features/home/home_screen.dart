import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';
import 'package:atsvs_outpass_app/features/mess/mess_screen.dart';
import 'package:atsvs_outpass_app/features/requests/new_request_screen.dart';
import 'package:atsvs_outpass_app/features/requests/request_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    // Events + requests now come live from Firestore.
    final eventsAsync = ref.watch(eventsStreamProvider);
    final requestsAsync =
        ref.watch(requestsForRollProvider(app.activeRoll ?? ''));
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATSVS College'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
            ),
          ),
        ),
        actions: [
          // Mess booking is for students only.
          if (app.role == UserRole.student)
            IconButton(
              tooltip: 'Mess booking',
              icon: const Icon(Icons.restaurant_menu),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessScreen()),
              ),
            ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context, app.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewRequestScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(app.role == UserRole.student ? 'Request' : 'Apply Leave'),
      ),
      body: Builder(
        builder: (context) {
          final student = app.activeStudent;
          if (student == null) {
            return const Center(child: Text('No student linked.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _ProfileCard(student: student, role: app.role!),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'College Events',
                icon: Icons.campaign_outlined,
              ),
              const SizedBox(height: 10),
              eventsAsync.when(
                data: (evs) => _EventsStrip(events: evs),
                loading: () => const SizedBox(
                  height: 132,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Could not load events',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Requests',
                icon: Icons.assignment_outlined,
              ),
              const SizedBox(height: 6),
              ...requestsAsync.when<List<Widget>>(
                data: (reqs) => reqs.isEmpty
                    ? [_EmptyRequests(role: app.role!)]
                    : reqs.map((r) => _RequestTile(request: r)).toList(),
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                ],
                error: (e, _) => [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load requests',
                        style: TextStyle(color: Colors.grey.shade600)),
                  )
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Student student;
  final UserRole role;
  const _ProfileCard({required this.student, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient header with avatar, name and role chip.
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('${student.course} • ${student.year}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role == UserRole.parent ? 'Parent' : 'Student',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // White info strip.
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                _infoRow(Icons.badge_outlined,
                    'Roll ${student.rollNo}   •   Room ${student.hostelRoom}'),
                const SizedBox(height: 10),
                _infoRow(
                  role == UserRole.student
                      ? Icons.family_restroom
                      : Icons.person_outline,
                  role == UserRole.student
                      ? 'Parent: ${student.parentName}  •  ${student.parentPhone}'
                      : 'Guardian: ${student.parentName}  •  ${student.parentPhone}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5)),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B3A1E))),
      ],
    );
  }
}

class _EventsStrip extends StatelessWidget {
  final List<CollegeEvent> events;
  const _EventsStrip({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('No events posted.',
          style: TextStyle(color: Colors.grey.shade600));
    }
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final e = events[i];
          final hasImage = e.imageUrls.isNotEmpty;
          return GestureDetector(
            onTap: () => _showEvent(context, e),
            child: Container(
              // Gradient border.
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF66BB6A), Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                width: 300,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE8F5E9),
                      Color(0xFFC8E6C9),
                      Color(0xFFFFFFFF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(19.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage)
                      _EventImageCarousel(imageUrls: e.imageUrls),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (e.date != null)
                              Row(
                                children: [
                                  const Icon(Icons.event,
                                      size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  Text(_fmt(e.date!),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            if (e.date != null) const SizedBox(height: 6),
                            if (e.title.isNotEmpty)
                              Text(e.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17)),
                            if (e.title.isNotEmpty) const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                e.description,
                                maxLines: hasImage ? 2 : 6,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static void _showEvent(BuildContext context, CollegeEvent e) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.imageUrls.isNotEmpty)
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: PageView(
                    children: e.imageUrls
                        .map((u) => Image.network(u,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFEFEFEF),
                                child: const Center(
                                    child: Icon(Icons.broken_image)))))
                        .toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.date != null)
                      Row(
                        children: [
                          const Icon(Icons.event,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(_fmt(e.date!),
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    if (e.title.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(e.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(e.description,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Colors.grey.shade800)),
                    ],
                    if (e.imageUrls.length > 1) ...[
                      const SizedBox(height: 12),
                      Text('${e.imageUrls.length} photos — swipe to view',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Auto-sliding image carousel for an event card (with dot indicators).
/// Tapping the card still opens the full swipeable gallery.
class _EventImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  const _EventImageCarousel({required this.imageUrls});

  @override
  State<_EventImageCarousel> createState() => _EventImageCarouselState();
}

class _EventImageCarouselState extends State<_EventImageCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrls.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        _index = (_index + 1) % widget.imageUrls.length;
        _controller.animateToPage(_index,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 185,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            // Auto-slide only (manual swipe is in the tap-to-open gallery), so
            // it doesn't fight the horizontal events strip.
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (c, i) => Image.network(
              widget.imageUrls[i],
              height: 185,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEFEFEF),
                  child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey))),
              loadingBuilder: (c, child, p) => p == null
                  ? child
                  : const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final AppRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = request.overallStatus;
    final color = AppTheme.statusColor(status.label);
    final isOutpass = request.type == RequestType.outpass;
    final typeLabel = isOutpass && request.outpassKind != null
        ? request.outpassKind!.label
        : request.type.label;
    return GradientCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(requestId: request.id),
        ),
      ),
      child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored status accent bar.
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                              isOutpass
                                  ? Icons.timer_outlined
                                  : Icons.home_outlined,
                              color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(typeLabel,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(request.reason,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.5)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      isOutpass
                                          ? '${_fmtDate(request.fromDate)}  ${_fmtTime(request.fromDate)}–${_fmtTime(request.toDate)}'
                                          : '${_fmtDate(request.fromDate)} → ${_fmtDate(request.toDate)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                              if (request.gateStatus != GateStatus.notOut) ...[
                                const SizedBox(height: 4),
                                Text('Gate: ${request.gateStatus.label}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatusChip(label: status.label, color: color),
                            const SizedBox(height: 6),
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade400, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  final UserRole role;
  const _EmptyRequests({required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No requests yet',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            role == UserRole.student
                ? 'Tap “Request” for an outpass or leave.'
                : 'Tap “Apply Leave” to raise a request.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
