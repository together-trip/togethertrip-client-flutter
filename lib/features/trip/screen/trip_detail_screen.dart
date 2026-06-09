import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../notification/screen/notification_list_screen.dart';
import '../../post/screen/post_form_sheet.dart';
import '../../post/service/post_service.dart';
import '../../transaction/screen/expense_form_sheet.dart';
import '../../transaction/service/transaction_service.dart';
import '../service/trip_service.dart';
import 'trip_form_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  final TripService? tripService;
  final PostService? postService;
  final TransactionService? transactionService;
  final ValueChanged<bool>? onClose;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.tripService,
    this.postService,
    this.transactionService,
    this.onClose,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripService _tripService;
  late final PostService _postService;
  late final TransactionService _transactionService;
  late final ScrollController _scrollController;

  final List<PostSummary> _posts = [];
  final Map<int, List<PostAttachment>> _attachmentsByPostId = {};
  final Map<int, TransactionSummary> _transactionsById = {};

  TripDetail? _trip;
  int? _currentUserId;
  int? _currentParticipantId;
  _PostFeedFilter _selectedFilter = _PostFeedFilter.all;
  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  String? _nextCursor;
  String? _errorMessage;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    _postService = widget.postService ?? PostService();
    _transactionService = widget.transactionService ?? TransactionService();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trip = await _tripService.getTrip(widget.tripId);
      final currentUser = await _tripService.getCurrentUser();
      int? currentParticipantId;
      try {
        currentParticipantId = (await _tripService.getMyTripParticipant(
          widget.tripId,
        )).id;
      } catch (_) {
        currentParticipantId = null;
      }

      final page = await _postService.getPosts(
        widget.tripId,
        postType: _selectedFilter.postType,
      );
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _currentUserId = currentUser.id;
        _currentParticipantId = currentParticipantId;
        _posts
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
        _attachmentsByPostId.clear();
        _transactionsById.clear();
      });
      _enhancePosts(page.items);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '여행 상세를 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadInitial();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _errorMessage = null;
    });

    try {
      final page = await _postService.getPosts(
        widget.tripId,
        postType: _selectedFilter.postType,
      );
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
        _attachmentsByPostId.clear();
        _transactionsById.clear();
      });
      _enhancePosts(page.items);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '게시글을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasNext || _nextCursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final page = await _postService.getPosts(
        widget.tripId,
        postType: _selectedFilter.postType,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
      _enhancePosts(page.items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('추가 게시글을 불러오지 못했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _enhancePosts(List<PostSummary> posts) async {
    for (final post in posts) {
      if (post.attachments.isNotEmpty) {
        _attachmentsByPostId[post.id] = post.attachments;
      } else {
        _loadAttachments(post);
      }
      if (post.transactionId != null) {
        _loadTransaction(post.transactionId!);
      }
    }
  }

  Future<void> _loadAttachments(PostSummary post) async {
    try {
      final detail = await _postService.getPost(widget.tripId, post.id);
      if (!mounted || detail.attachments.isEmpty) return;
      setState(() => _attachmentsByPostId[post.id] = detail.attachments);
    } catch (_) {
      // Attachment enhancement is optional for feed rendering.
    }
  }

  Future<void> _loadTransaction(int transactionId) async {
    if (_transactionsById.containsKey(transactionId)) return;
    try {
      final transaction = await _transactionService.getTransaction(
        widget.tripId,
        transactionId,
      );
      if (!mounted) return;
      setState(() => _transactionsById[transactionId] = transaction.summary);
    } catch (_) {
      // Transaction enhancement is optional for feed rendering.
    }
  }

  Future<void> _selectFilter(_PostFeedFilter filter) async {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    await _loadPosts();
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationListScreen()),
    );
  }

  void _showSettlementPreparing() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('정산 기능은 준비 중입니다.')));
  }

  Future<void> _openInfoSheet() async {
    final trip = _trip;
    if (trip == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return _TripInfoSheet(
          trip: trip,
          canManageTrip: _canManageTrip,
          onEdit: () async {
            Navigator.of(context).pop(false);
            await _openEditTrip();
          },
          onDelete: () async {
            Navigator.of(context).pop(false);
            await _confirmDeleteTrip();
          },
        );
      },
    );
    if (changed == true) await _refreshAll();
  }

  Future<void> _openEditTrip() async {
    final trip = _trip;
    if (trip == null) return;

    final updated = await Navigator.of(context).push<TripDetail>(
      MaterialPageRoute<TripDetail>(
        builder: (_) =>
            TripFormScreen(tripService: _tripService, initialTrip: trip),
      ),
    );

    if (updated != null) {
      _changed = true;
      await _refreshAll();
    }
  }

  Future<void> _confirmDeleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('여행 삭제'),
          content: const Text('이 여행을 삭제하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCC0000),
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await _tripService.deleteTrip(widget.tripId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('여행 삭제에 실패했습니다: $e')));
    }
  }

  Future<void> _openCreateChooser() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '무엇을 등록할까요?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit_note_outlined),
                  title: const Text('기록'),
                  onTap: () => Navigator.of(context).pop('RECORD'),
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('소비'),
                  onTap: () => Navigator.of(context).pop('EXPENSE'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    if (selected == 'EXPENSE') {
      await _openExpenseForm();
      return;
    }
    await _openPostForm(postType: selected);
  }

  Future<void> _openExpenseForm() async {
    final trip = _trip;
    if (trip == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return ExpenseFormSheet(
          trip: trip,
          currentParticipantId: _currentParticipantId,
          onSubmit: ({required transactionInput, required postInput}) async {
            final transaction = await _transactionService.createTransaction(
              widget.tripId,
              transactionInput,
            );
            await _postService.createPost(
              widget.tripId,
              PostFormInput(
                transactionId: transaction.summary.id,
                title: postInput.title,
                category: postInput.category,
                content: postInput.content,
                postType: 'EXPENSE',
                occurredAt: postInput.occurredAt,
                placeName: postInput.placeName,
                latitude: postInput.latitude,
                longitude: postInput.longitude,
                attachments: postInput.attachments,
              ),
            );
          },
        );
      },
    );

    if (changed == true) {
      _changed = true;
      if (_selectedFilter == _PostFeedFilter.record) {
        setState(() => _selectedFilter = _PostFeedFilter.all);
      }
      await _loadPosts();
    }
  }

  Future<void> _openPostForm({
    required String postType,
    PostDetail? initialPost,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return PostFormSheet(
          postType: postType,
          initialPost: initialPost,
          onSubmit: (input) async {
            if (initialPost == null) {
              await _postService.createPost(widget.tripId, input);
            } else {
              await _postService.updatePost(
                widget.tripId,
                initialPost.id,
                input,
              );
            }
          },
        );
      },
    );
    if (changed == true) {
      _changed = true;
      if (initialPost == null &&
          _selectedFilter.postType != null &&
          _selectedFilter.postType != postType) {
        setState(() => _selectedFilter = _PostFeedFilter.all);
      }
      await _loadPosts();
    }
  }

  Future<void> _openPostActions(PostSummary post) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('수정'),
                  onTap: () => Navigator.of(context).pop('edit'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFCC0000),
                  ),
                  title: const Text(
                    '삭제',
                    style: TextStyle(color: Color(0xFFCC0000)),
                  ),
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'edit') {
      await _editPost(post);
    } else if (action == 'delete') {
      await _confirmDeletePost(post);
    }
  }

  Future<void> _editPost(PostSummary post) async {
    try {
      final detail = await _postService.getPost(widget.tripId, post.id);
      if (!mounted) return;
      await _openPostForm(postType: detail.postType, initialPost: detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('게시글을 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _confirmDeletePost(PostSummary post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('이 게시글을 삭제하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCC0000),
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await _postService.deletePost(widget.tripId, post.id);
      _changed = true;
      await _loadPosts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('게시글 삭제에 실패했습니다: $e')));
    }
  }

  Future<void> _openComments(PostSummary post) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return _CommentsSheet(
          tripId: widget.tripId,
          postId: post.id,
          currentParticipantId: _currentParticipantId,
          postService: _postService,
        );
      },
    );
    if (changed == true) {
      _changed = true;
      await _loadPosts();
    }
  }

  bool get _canManageTrip {
    final trip = _trip;
    return trip != null &&
        _currentUserId != null &&
        trip.ownerUserId == _currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final onClose = widget.onClose;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (onClose != null) {
          onClose(_changed);
          return;
        }
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Text(
            _trip?.title ?? '여행',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: onClose == null
              ? null
              : IconButton(
                  onPressed: () => onClose(_changed),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '뒤로',
                ),
          actions: [
            IconButton(
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_none, size: 22),
              tooltip: '알림',
            ),
            IconButton(
              onPressed: _openInfoSheet,
              icon: const Icon(Icons.info_outline, size: 22),
              tooltip: '여행 정보',
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _PostFeedTabs(
              selectedFilter: _selectedFilter,
              onSelect: _selectFilter,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateChooser,
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final trip = _trip;
    if (trip == null) {
      return _FullErrorState(
        message: _errorMessage ?? '여행 상세를 불러오지 못했습니다.',
        onRetry: _loadInitial,
      );
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return _FullErrorState(message: _errorMessage!, onRetry: _loadInitial);
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _TripFeedHeader(
              trip: trip,
              onSettlementTap: _showSettlementPreparing,
            ),
          ),
          if (_isLoadingPosts)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFeedState(filter: _selectedFilter),
            )
          else
            SliverList.separated(
              itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, index) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF0F0F0),
              ),
              itemBuilder: (context, index) {
                if (index >= _posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final post = _posts[index];
                return _PostFeedCard(
                  post: post,
                  attachments: _attachmentsByPostId[post.id] ?? const [],
                  transaction: post.transactionId == null
                      ? null
                      : _transactionsById[post.transactionId],
                  showActions:
                      _currentParticipantId != null &&
                      _currentParticipantId == post.authorParticipantId,
                  onActionsTap: () => _openPostActions(post),
                  onCommentsTap: () => _openComments(post),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

class _TripFeedHeader extends StatelessWidget {
  final TripDetail trip;
  final VoidCallback onSettlementTap;

  const _TripFeedHeader({required this.trip, required this.onSettlementTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_dateRangeLabel(trip.startDate, trip.endDate)} · ${_countrySummary(trip)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onSettlementTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '정산 ${_settlementStatusLabel(trip.settlementStatus)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostFeedTabs extends StatelessWidget {
  final _PostFeedFilter selectedFilter;
  final ValueChanged<_PostFeedFilter> onSelect;

  const _PostFeedTabs({required this.selectedFilter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        spacing: 8,
        children: _PostFeedFilter.values.map((filter) {
          final selected = selectedFilter == filter;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(filter),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1A1A1A) : Colors.white,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE2E2E2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF4A4A4A),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PostFeedCard extends StatefulWidget {
  final PostSummary post;
  final List<PostAttachment> attachments;
  final TransactionSummary? transaction;
  final bool showActions;
  final VoidCallback onActionsTap;
  final VoidCallback onCommentsTap;

  const _PostFeedCard({
    required this.post,
    required this.attachments,
    required this.transaction,
    required this.showActions,
    required this.onActionsTap,
    required this.onCommentsTap,
  });

  @override
  State<_PostFeedCard> createState() => _PostFeedCardState();
}

class _PostFeedCardState extends State<_PostFeedCard> {
  final PageController _pageController = PageController();
  bool _isExpanded = false;
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post.contentPreview?.trim() ?? '';
    final shouldClamp = content.length > 110;
    final visibleContent = _isExpanded || !shouldClamp
        ? content
        : '${content.substring(0, min(content.length, 110))}...';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.post.authorDisplayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                widget.post.category,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
              if (widget.showActions) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onActionsTap,
                  icon: const Icon(Icons.more_horiz, size: 22),
                  tooltip: '게시글 메뉴',
                ),
              ],
            ],
          ),
          if (widget.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AttachmentCarousel(
              attachments: widget.attachments,
              pageController: _pageController,
              pageIndex: _pageIndex,
              onPageChanged: (value) => setState(() => _pageIndex = value),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            widget.post.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              visibleContent,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            if (shouldClamp)
              TextButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_isExpanded ? '접기' : '더 보기'),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.post.occurredAt != null)
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: _dateOnlyLabel(widget.post.occurredAt!),
                ),
              if ((widget.post.placeName ?? '').isNotEmpty)
                _MetaChip(
                  icon: Icons.place_outlined,
                  label: widget.post.placeName!,
                ),
              if (widget.transaction != null)
                _MetaChip(
                  icon: Icons.payments_outlined,
                  label: _moneyLabel(widget.transaction!),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: widget.onCommentsTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '댓글 ${widget.post.commentCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCarousel extends StatelessWidget {
  final List<PostAttachment> attachments;
  final PageController pageController;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  const _AttachmentCarousel({
    required this.attachments,
    required this.pageController,
    required this.pageIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: attachments.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                final imageUrl = attachment.thumbnailUrl?.isNotEmpty == true
                    ? attachment.thumbnailUrl!
                    : attachment.fileUrl;
                final isVideo = attachment.attachmentType == 'VIDEO';
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFFF3F3F3),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                              ),
                            ),
                          ),
                    ),
                    if (isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                  ],
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${pageIndex + 1}/${attachments.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            if (attachments.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(attachments.length, (index) {
                    final selected = index == pageIndex;
                    return Container(
                      width: selected ? 7 : 5,
                      height: selected ? 7 : 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6B6B6B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
        ),
      ],
    );
  }
}

class _TripInfoSheet extends StatelessWidget {
  final TripDetail trip;
  final bool canManageTrip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TripInfoSheet({
    required this.trip,
    required this.canManageTrip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '여행 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              _Section(
                title: '상태',
                children: [
                  _InfoRow(
                    label: '여행',
                    value: _tripStatusLabel(trip.tripStatus),
                  ),
                  _InfoRow(
                    label: '정산',
                    value: _settlementStatusLabel(trip.settlementStatus),
                  ),
                ],
              ),
              _Section(
                title: '국가',
                children: trip.countries.isEmpty
                    ? const [_EmptyLine(text: '등록된 국가가 없습니다.')]
                    : trip.countries
                          .map(
                            (country) => _InfoRow(
                              label: country.countryCode,
                              value: country.countryName,
                            ),
                          )
                          .toList(),
              ),
              _Section(
                title: '참여자',
                children: trip.participants.isEmpty
                    ? const [_EmptyLine(text: '등록된 참여자가 없습니다.')]
                    : trip.participants
                          .map(
                            (participant) => _InfoRow(
                              label: _roleLabel(participant.participantRole),
                              value: participant.displayName,
                            ),
                          )
                          .toList(),
              ),
              if (canManageTrip) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('여행 수정'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('여행 삭제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCC0000),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final int tripId;
  final int postId;
  final int? currentParticipantId;
  final PostService postService;

  const _CommentsSheet({
    required this.tripId,
    required this.postId,
    required this.currentParticipantId,
    required this.postService,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final List<PostComment> _comments = [];
  String? _nextCursor;
  bool _hasNext = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _changed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await widget.postService.getComments(
        widget.tripId,
        widget.postId,
      );
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '댓글을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasNext || _nextCursor == null) return;
    try {
      final page = await widget.postService.getComments(
        widget.tripId,
        widget.postId,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('추가 댓글을 불러오지 못했습니다.')));
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.postService.createComment(
        widget.tripId,
        widget.postId,
        content,
      );
      _controller.clear();
      _changed = true;
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 작성에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete(PostComment comment) async {
    try {
      await widget.postService.deleteComment(
        widget.tripId,
        widget.postId,
        comment.id,
      );
      _changed = true;
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 삭제에 실패했습니다: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '댓글',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _errorMessage != null
                      ? _FullErrorState(
                          message: _errorMessage!,
                          onRetry: _loadComments,
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _comments.length + (_hasNext ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _comments.length) {
                              return TextButton(
                                onPressed: _loadMore,
                                child: const Text('더 보기'),
                              );
                            }
                            final comment = _comments[index];
                            final canDelete =
                                widget.currentParticipantId != null &&
                                widget.currentParticipantId ==
                                    comment.authorParticipantId;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.authorDisplayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(comment.content),
                                      ],
                                    ),
                                  ),
                                  if (canDelete)
                                    IconButton(
                                      onPressed: () => _delete(comment),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      tooltip: '댓글 삭제',
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    12 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isSubmitting,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '댓글을 입력하세요',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        tooltip: '댓글 작성',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  final _PostFeedFilter filter;

  const _EmptyFeedState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_note_outlined, size: 44),
            const SizedBox(height: 14),
            Text(
              filter.emptyTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              filter.emptyDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FullErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      children: [
        const Text(
          '화면을 불러오지 못했습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}

enum _PostFeedFilter {
  all(label: '전체', postType: null),
  record(label: '기록', postType: 'RECORD'),
  expense(label: '소비', postType: 'EXPENSE');

  final String label;
  final String? postType;

  const _PostFeedFilter({required this.label, required this.postType});

  String get emptyTitle {
    return switch (this) {
      _PostFeedFilter.all => '아직 기록이 없어요',
      _PostFeedFilter.record => '아직 남긴 기록이 없어요',
      _PostFeedFilter.expense => '아직 등록한 소비가 없어요',
    };
  }

  String get emptyDescription {
    return switch (this) {
      _PostFeedFilter.all => '여행의 첫 순간을 남겨보세요',
      _PostFeedFilter.record => '여행의 순간을 글로 남겨보세요',
      _PostFeedFilter.expense => '여행 중 쓴 돈을 남기면 정산이 쉬워져요',
    };
  }
}

String _countrySummary(TripDetail trip) {
  if (trip.countries.isEmpty) return trip.defaultCurrency;
  if (trip.countries.length == 1) return trip.countries.single.countryName;
  return '${trip.countries.first.countryName} 외 ${trip.countries.length - 1}';
}

String _dateRangeLabel(String? startDate, String? endDate) {
  if ((startDate == null || startDate.isEmpty) &&
      (endDate == null || endDate.isEmpty)) {
    return '날짜 미정';
  }
  return '${startDate ?? '시작 미정'} - ${endDate ?? '종료 미정'}';
}

String _dateOnlyLabel(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

String _tripStatusLabel(String status) {
  return switch (status) {
    'ONGOING' => '진행중',
    'COMPLETED' => '완료',
    _ => '예정',
  };
}

String _settlementStatusLabel(String status) {
  return switch (status) {
    'IN_PROGRESS' => '진행중',
    'SETTLED' => '완료',
    _ => '미시작',
  };
}

String _roleLabel(String role) {
  return role == 'LEADER' ? '방장' : '동행자';
}

String _moneyLabel(TransactionSummary transaction) {
  final amount = _formatAmount(transaction.amount);
  return switch (transaction.currency) {
    'JPY' => '¥$amount',
    'KRW' => '₩$amount',
    'USD' => '\$$amount',
    _ => '${transaction.currency} $amount',
  };
}

String _formatAmount(double amount) {
  final fixed = amount.truncateToDouble() == amount
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final buffer = StringBuffer();
  for (var i = 0; i < parts.first.length; i++) {
    if (i > 0 && (parts.first.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(parts.first[i]);
  }
  if (parts.length == 2) {
    final decimals = parts[1].replaceFirst(RegExp(r'0+$'), '');
    if (decimals.isNotEmpty) buffer.write('.$decimals');
  }
  return buffer.toString();
}
