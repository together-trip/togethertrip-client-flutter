import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../notification/screen/notification_list_screen.dart';
import '../../notification/widget/notification_badge_button.dart';
import '../../post/screen/post_form_sheet.dart';
import '../../post/service/post_service.dart';
import '../../settlement/screen/settlement_screen.dart';
import '../../transaction/screen/expense_form_sheet.dart';
import '../../transaction/service/transaction_service.dart';
import '../service/trip_service.dart';
import '../widget/trip_invite_participant_sheets.dart';
import 'trip_form_screen.dart';
import 'trip_recap_screen.dart';

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
  final Map<int, TransactionDetail> _transactionsById = {};

  TripDetail? _trip;
  TripRecapStatus? _recapStatus;
  int? _currentUserId;
  int? _currentParticipantId;
  _PostFeedFilter _selectedFilter = _PostFeedFilter.all;
  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isLoadingMore = false;
  bool _isLoadingRecapStatus = false;
  bool _isSubmittingRecap = false;
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
      final recapStatus = await _loadRecapStatusSilently();
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
        _recapStatus = recapStatus;
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

  Future<TripRecapStatus?> _loadRecapStatusSilently() async {
    try {
      return await _tripService.getRecapStatus(widget.tripId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _reloadRecapStatus() async {
    setState(() {
      _isLoadingRecapStatus = true;
      _errorMessage = null;
    });

    try {
      final status = await _tripService.getRecapStatus(widget.tripId);
      if (!mounted) return;
      setState(() => _recapStatus = status);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recap 상태를 불러오지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingRecapStatus = false);
    }
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

  Future<void> _openTransactionInfo(TransactionDetail transaction) async {
    final trip = _trip;
    if (trip == null) return;

    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _TransactionInfoSheet(
          transaction: transaction,
          participants: trip.participants,
        );
      },
    );
  }

  Future<void> _openTransactionInfoById(int transactionId) async {
    final cached = _transactionsById[transactionId];
    if (cached != null) {
      await _openTransactionInfo(cached);
      return;
    }

    try {
      final transaction = await _transactionService.getTransaction(
        widget.tripId,
        transactionId,
      );
      if (!mounted) return;
      setState(() => _transactionsById[transactionId] = transaction);
      await _openTransactionInfo(transaction);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('소비 정보를 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _selectFilter(_PostFeedFilter filter) async {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    await _loadPosts();
  }

  Future<void> _openNotifications() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationListScreen(tripService: _tripService),
      ),
    );
  }

  Future<void> _openSettlement() async {
    final trip = _trip;
    if (trip == null) return;
    final currentParticipantId = _currentParticipantId;
    if (currentParticipantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('내 여행 참여자 정보를 불러오지 못했습니다. 다시 시도해주세요.'),
          action: SnackBarAction(label: '재시도', onPressed: _refreshAll),
        ),
      );
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SettlementScreen(
          tripId: trip.id,
          tripTitle: trip.title,
          isOwner: _canManageTrip,
          currentParticipantId: currentParticipantId,
          tripSettlementStatus: trip.settlementStatus,
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _refreshAll();
    }
  }

  Future<void> _openRecap() async {
    final status = _recapStatus;
    if (status == null || !status.available || _isSubmittingRecap) return;

    switch (status.status) {
      case TripRecapStatusValue.none:
        await _requestRecap(isRetry: false);
      case TripRecapStatusValue.creating:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recap을 만들고 있습니다. 완료되면 알림으로 알려드릴게요.')),
        );
      case TripRecapStatusValue.completed:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TripRecapScreen(
              tripId: widget.tripId,
              tripRecapId: status.recapId,
              tripService: _tripService,
            ),
          ),
        );
      case TripRecapStatusValue.failed:
        await _requestRecap(isRetry: true);
    }
  }

  Future<void> _requestRecap({required bool isRetry}) async {
    final style = await _selectRecapStyle();
    if (style == null || _isSubmittingRecap) return;

    setState(() => _isSubmittingRecap = true);
    try {
      final result = isRetry
          ? await _tripService.retryRecap(widget.tripId, style)
          : await _tripService.createRecap(widget.tripId, style);
      if (!mounted) return;
      setState(() {
        _recapStatus = TripRecapStatus(
          available: true,
          status: result.status,
          recapId: result.recapId,
          style: style,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recap 생성 요청을 보냈습니다.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      await _reloadRecapStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recap 요청에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isSubmittingRecap = false);
    }
  }

  Future<TripRecapStyle?> _selectRecapStyle() {
    return showAppBottomSheet<TripRecapStyle>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recap 스타일',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final style in TripRecapStyle.values) ...[
                  _CreateOptionTile(
                    key: ValueKey('recapStyle${style.apiValue}'),
                    icon: style == TripRecapStyle.photo
                        ? Icons.photo_camera_outlined
                        : Icons.palette_outlined,
                    title: style == TripRecapStyle.photo ? '사진' : '일러스트',
                    subtitle: style.label,
                    selected: false,
                    onTap: () => Navigator.of(context).pop(style),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openInfoSheet() async {
    final trip = _trip;
    if (trip == null) return;
    final changed = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _TripInfoSheet(
          trip: trip,
          canManageTrip: _canManageTrip,
          onManageParticipants: () async {
            Navigator.of(context).pop(false);
            await _openParticipantManager();
          },
          onCreateInviteLink: () async {
            Navigator.of(context).pop(false);
            await _createAndShowInviteLink();
          },
          onCreateInviteCode: () async {
            Navigator.of(context).pop(false);
            await _createAndShowInviteCode();
          },
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

  Future<void> _createAndShowInviteLink() async {
    try {
      final invite = await _tripService.createInviteLink(widget.tripId);
      if (!mounted) return;
      await _showInviteSheet(
        title: '초대 링크',
        value: invite.inviteUrl,
        copiedMessage: '초대 링크를 복사했습니다.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초대 링크 생성에 실패했습니다: $e')));
    }
  }

  Future<void> _createAndShowInviteCode() async {
    try {
      final invite = await _tripService.createInviteCode(widget.tripId);
      if (!mounted) return;
      await _showInviteSheet(
        title: '초대 코드',
        value: invite.code ?? invite.token,
        copiedMessage: '초대 코드를 복사했습니다.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초대 코드 생성에 실패했습니다: $e')));
    }
  }

  Future<void> _showInviteSheet({
    required String title,
    required String value,
    required String copiedMessage,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        return TripInviteValueSheet(
          title: title,
          value: value,
          copiedMessage: copiedMessage,
        );
      },
    );
  }

  Future<void> _openParticipantManager() async {
    final trip = _trip;
    if (trip == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return TripParticipantManagerSheet(
          trip: trip,
          tripService: _tripService,
        );
      },
    );

    if (changed == true) {
      _changed = true;
      await _refreshAll();
    }
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
              style: AppButtonStyles.dangerText(),
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
    final isExpenseLocked = _isExpenseLockedBySettlement;
    final defaultPostType = _selectedFilter == _PostFeedFilter.expense
        ? 'EXPENSE'
        : 'RECORD';
    final selected = await showAppBottomSheet<String>(
      context: context,
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
                _CreateOptionTile(
                  key: const ValueKey('createRecordOption'),
                  icon: Icons.edit_outlined,
                  title: '기록',
                  selected: defaultPostType == 'RECORD',
                  onTap: () => Navigator.of(context).pop('RECORD'),
                ),
                const SizedBox(height: 8),
                _CreateOptionTile(
                  key: const ValueKey('createExpenseOption'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: '소비',
                  subtitle: isExpenseLocked ? _expenseLockedMessage : null,
                  selected: !isExpenseLocked && defaultPostType == 'EXPENSE',
                  enabled: !isExpenseLocked,
                  onTap: isExpenseLocked
                      ? null
                      : () => Navigator.of(context).pop('EXPENSE'),
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

  bool get _isExpenseLockedBySettlement {
    return _trip?.settlementStatus != 'NOT_STARTED';
  }

  bool _isLockedExpensePost(PostSummary post) {
    return post.postType == 'EXPENSE' && _isExpenseLockedBySettlement;
  }

  Future<void> _openExpenseForm() async {
    final trip = _trip;
    if (trip == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return ExpenseFormSheet(
          trip: trip,
          currentParticipantId: _currentParticipantId,
          onSubmit: ({required transactionInput, required postInput}) async {
            await _postService.createExpensePost(
              widget.tripId,
              ExpensePostFormInput(
                transactionInput: transactionInput,
                postInput: postInput,
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
    final changed = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return PostFormSheet(
          tripId: widget.tripId,
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
    final isLockedExpensePost = _isLockedExpensePost(post);
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLockedExpensePost)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Text(
                      _expensePostLockedMessage,
                      style: TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ListTile(
                  key: const ValueKey('postEditAction'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('수정'),
                  enabled: !isLockedExpensePost,
                  onTap: isLockedExpensePost
                      ? null
                      : () => Navigator.of(context).pop('edit'),
                ),
                ListTile(
                  key: const ValueKey('postDeleteAction'),
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: isLockedExpensePost
                        ? AppColors.textSubtle
                        : AppColors.danger,
                  ),
                  title: Text(
                    '삭제',
                    style: TextStyle(
                      color: isLockedExpensePost
                          ? AppColors.textSubtle
                          : AppColors.danger,
                    ),
                  ),
                  enabled: !isLockedExpensePost,
                  onTap: isLockedExpensePost
                      ? null
                      : () => Navigator.of(context).pop('delete'),
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
      if (detail.postType == 'EXPENSE') {
        await _openEditExpenseForm(detail);
        return;
      }
      await _openPostForm(postType: detail.postType, initialPost: detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('게시글을 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _openEditExpenseForm(PostDetail post) async {
    final trip = _trip;
    final transactionId = post.transactionId;
    if (trip == null || transactionId == null) return;

    try {
      final transaction =
          _transactionsById[transactionId] ??
          await _transactionService.getTransaction(
            widget.tripId,
            transactionId,
          );
      if (!mounted) return;
      _transactionsById[transactionId] = transaction;
      final changed = await showAppBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) {
          return ExpenseFormSheet(
            trip: trip,
            currentParticipantId: _currentParticipantId,
            initialPost: post,
            initialTransaction: transaction,
            onSubmit: ({required transactionInput, required postInput}) async {
              await _postService.updateExpensePost(
                widget.tripId,
                post.id,
                ExpensePostFormInput(
                  transactionInput: transactionInput,
                  postInput: postInput,
                ),
              );
            },
          );
        },
      );

      if (changed == true) {
        _changed = true;
        _transactionsById.remove(transactionId);
        await _loadPosts();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('소비 정보를 불러오지 못했습니다: $e')));
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
              style: AppButtonStyles.dangerText(),
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
    final changed = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          title: Text(
            _trip?.title ?? '여행',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          leading: onClose == null
              ? null
              : IconButton(
                  onPressed: () => onClose(_changed),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: '뒤로',
                ),
          actions: [
            NotificationBadgeButton(onPressed: _openNotifications),
            if (_canManageTrip)
              IconButton(
                key: const ValueKey('editTripButton'),
                onPressed: _openEditTrip,
                icon: const Icon(Icons.edit_outlined, size: 22),
                tooltip: '여행 수정',
              ),
            IconButton(
              onPressed: _openInfoSheet,
              icon: const Icon(Icons.more_horiz, size: 22),
              tooltip: '여행 메뉴',
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: _PostFeedTabs(
              selectedFilter: _selectedFilter,
              onSelect: _selectFilter,
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 112),
          child: FloatingActionButton(
            onPressed: _openCreateChooser,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
          ),
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
              recapStatus: _recapStatus,
              isLoadingRecapStatus: _isLoadingRecapStatus,
              isSubmittingRecap: _isSubmittingRecap,
              onSettlementTap: _openSettlement,
              onRecapTap: _openRecap,
              onRecapStatusRetry: _reloadRecapStatus,
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
              separatorBuilder: (_, index) => const Divider(indent: 20),
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
                  onTransactionTap: post.transactionId == null
                      ? null
                      : () => _openTransactionInfoById(post.transactionId!),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

class _CreateOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _CreateOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? AppColors.ink : AppColors.textSubtle;
    final titleColor = enabled ? AppColors.ink : AppColors.textSubtle;
    final borderColor = selected ? AppColors.ink : const Color(0xFFE0E0E0);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F4F4) : Colors.white,
          border: Border.all(
            color: enabled ? borderColor : const Color(0xFFE0E0E0),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TripFeedHeader extends StatelessWidget {
  final TripDetail trip;
  final TripRecapStatus? recapStatus;
  final bool isLoadingRecapStatus;
  final bool isSubmittingRecap;
  final VoidCallback onSettlementTap;
  final VoidCallback onRecapTap;
  final VoidCallback onRecapStatusRetry;

  const _TripFeedHeader({
    required this.trip,
    required this.recapStatus,
    required this.isLoadingRecapStatus,
    required this.isSubmittingRecap,
    required this.onSettlementTap,
    required this.onRecapTap,
    required this.onRecapStatusRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_dateRangeLabel(trip.startDate, trip.endDate)} · ${_countrySummary(trip)} · ${trip.participants.length}명',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onSettlementTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.brandStrong,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '정산 ${_settlementDisplayStatusLabel(trip.effectiveSettlementDisplayStatus)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const Text(
                    '정산 보기',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppColors.textSubtle,
                  ),
                ],
              ),
            ),
          ),
          _TripRecapAction(
            status: recapStatus,
            isLoading: isLoadingRecapStatus,
            isSubmitting: isSubmittingRecap,
            onTap: onRecapTap,
            onRetry: onRecapStatusRetry,
          ),
        ],
      ),
    );
  }
}

class _TripRecapAction extends StatelessWidget {
  final TripRecapStatus? status;
  final bool isLoading;
  final bool isSubmitting;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  const _TripRecapAction({
    required this.status,
    required this.isLoading,
    required this.isSubmitting,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: _RecapActionShell(
          icon: Icons.auto_awesome,
          title: 'Recap 상태 확인 중',
          trailing: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (current == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _RecapActionShell(
          icon: Icons.error_outline,
          title: 'Recap 상태를 확인하지 못했어요',
          subtitle: '다시 시도해 주세요.',
          onTap: onRetry,
          trailing: const Icon(Icons.refresh_rounded, size: 20),
        ),
      );
    }
    if (!current.available) return const SizedBox.shrink();

    final action = _recapActionCopy(current.status);
    final disabled =
        isSubmitting || current.status == TripRecapStatusValue.creating;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _RecapActionShell(
        icon: action.icon,
        title: action.title,
        subtitle: action.subtitle,
        onTap: disabled ? null : onTap,
        trailing: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(action.trailingIcon, size: 20),
      ),
    );
  }
}

class _RecapActionShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _RecapActionShell({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RecapActionCopy {
  final IconData icon;
  final IconData trailingIcon;
  final String title;
  final String? subtitle;

  const _RecapActionCopy({
    required this.icon,
    required this.trailingIcon,
    required this.title,
    this.subtitle,
  });
}

_RecapActionCopy _recapActionCopy(TripRecapStatusValue status) {
  return switch (status) {
    TripRecapStatusValue.none => const _RecapActionCopy(
      icon: Icons.auto_awesome_outlined,
      trailingIcon: Icons.chevron_right_rounded,
      title: '지난 여행 Recap 만들기',
      subtitle: '사진 또는 일러스트 스타일을 선택해요.',
    ),
    TripRecapStatusValue.creating => const _RecapActionCopy(
      icon: Icons.hourglass_top,
      trailingIcon: Icons.lock_clock_outlined,
      title: 'Recap 생성 중',
      subtitle: '완료되면 알림으로 알려드릴게요.',
    ),
    TripRecapStatusValue.completed => const _RecapActionCopy(
      icon: Icons.auto_stories_outlined,
      trailingIcon: Icons.chevron_right_rounded,
      title: '지난 여행 Recap 보기',
    ),
    TripRecapStatusValue.failed => const _RecapActionCopy(
      icon: Icons.refresh_rounded,
      trailingIcon: Icons.chevron_right_rounded,
      title: 'Recap 다시 만들기',
      subtitle: '스타일을 다시 선택할 수 있어요.',
    ),
  };
}

class _PostFeedTabs extends StatelessWidget {
  final _PostFeedFilter selectedFilter;
  final ValueChanged<_PostFeedFilter> onSelect;

  const _PostFeedTabs({required this.selectedFilter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        spacing: 20,
        children: _PostFeedFilter.values.map((filter) {
          final selected = selectedFilter == filter;
          return InkWell(
            onTap: () => onSelect(filter),
            child: SizedBox(
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.brandStrong
                              : AppColors.textMuted,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 24 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
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
  final TransactionDetail? transaction;
  final bool showActions;
  final VoidCallback onActionsTap;
  final VoidCallback onCommentsTap;
  final VoidCallback? onTransactionTap;

  const _PostFeedCard({
    required this.post,
    required this.attachments,
    required this.transaction,
    required this.showActions,
    required this.onActionsTap,
    required this.onCommentsTap,
    required this.onTransactionTap,
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
    final isExpense = widget.post.postType == 'EXPENSE';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.lineSoft),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PostTypeBadge(postType: widget.post.postType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.post.authorDisplayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    widget.post.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSubtle,
                    ),
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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
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
                    style: AppButtonStyles.inlineText(),
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
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _FeedAction(
                    icon: Icons.chat_bubble_outline,
                    label: '댓글 ${widget.post.commentCount}',
                    onTap: widget.onCommentsTap,
                  ),
                  if (isExpense && widget.onTransactionTap != null)
                    _FeedAction(
                      icon: Icons.account_balance_wallet_outlined,
                      label: widget.transaction == null
                          ? '소비 정보'
                          : _moneyLabel(widget.transaction!.summary),
                      onTap: widget.onTransactionTap,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTypeBadge extends StatelessWidget {
  final String postType;

  const _PostTypeBadge({required this.postType});

  @override
  Widget build(BuildContext context) {
    final isExpense = postType == 'EXPENSE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isExpense ? '소비' : '기록',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FeedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FeedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
                final rawImageUrl = attachment.thumbnailUrl?.isNotEmpty == true
                    ? attachment.thumbnailUrl!
                    : attachment.fileUrl;
                final imageUrl = resolveApiUrl(rawImageUrl);
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
        Icon(icon, size: 15, color: AppColors.textSubtle),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
        ),
      ],
    );
  }
}

class _TripInfoSheet extends StatelessWidget {
  final TripDetail trip;
  final bool canManageTrip;
  final VoidCallback onManageParticipants;
  final VoidCallback onCreateInviteLink;
  final VoidCallback onCreateInviteCode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TripInfoSheet({
    required this.trip,
    required this.canManageTrip,
    required this.onManageParticipants,
    required this.onCreateInviteLink,
    required this.onCreateInviteCode,
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
                    value: _settlementDisplayStatusLabel(
                      trip.effectiveSettlementDisplayStatus,
                    ),
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
                  onPressed: onManageParticipants,
                  icon: const Icon(Icons.group_outlined, size: 18),
                  label: const Text('참여자 관리'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onCreateInviteLink,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('초대 링크 공유'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onCreateInviteCode,
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('초대 코드 공유'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('여행 수정'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('여행 삭제'),
                  style: AppButtonStyles.outlined(sideColor: AppColors.danger)
                      .copyWith(
                        foregroundColor: const WidgetStatePropertyAll(
                          AppColors.danger,
                        ),
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

class _TransactionInfoSheet extends StatelessWidget {
  final TransactionDetail transaction;
  final List<TripParticipant> participants;

  const _TransactionInfoSheet({
    required this.transaction,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.86,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '소비 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _moneyLabel(transaction.summary),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _TransactionPartySection(
                title: '결제자',
                rows: transaction.payments
                    .map(
                      (payment) => _TransactionPartyRowData(
                        participantName: _participantName(
                          participants,
                          payment.participantId,
                          payment.participantDisplayName,
                        ),
                        amount: _moneyLabelFor(
                          payment.amount,
                          transaction.summary.currency,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _TransactionPartySection(
                title: '부담자',
                rows: transaction.shares
                    .map(
                      (share) => _TransactionPartyRowData(
                        participantName: _participantName(
                          participants,
                          share.participantId,
                          share.participantDisplayName,
                        ),
                        amount: _moneyLabelFor(
                          share.shareAmount,
                          transaction.summary.currency,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionPartySection extends StatelessWidget {
  final String title;
  final List<_TransactionPartyRowData> rows;

  const _TransactionPartySection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text(
            '내역이 없습니다.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
          )
        else
          ...rows.map((row) => _TransactionPartyRow(row: row)),
      ],
    );
  }
}

class _TransactionPartyRow extends StatelessWidget {
  final _TransactionPartyRowData row;

  const _TransactionPartyRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFF2F2F2),
            child: Icon(
              Icons.person_outline,
              size: 18,
              color: Color(0xFF8A8A8A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.participantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(row.amount, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TransactionPartyRowData {
  final String participantName;
  final String amount;

  const _TransactionPartyRowData({
    required this.participantName,
    required this.amount,
  });
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
                                        Icons.delete_outline_rounded,
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
                          decoration: AppInputDecorations.filled(
                            hintText: '댓글을 입력하세요',
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
              style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
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
              style: const TextStyle(fontSize: 13, color: AppColors.textSubtle),
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
          style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
        ),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}

enum _PostFeedFilter {
  all(label: '전체', postType: null),
  record(label: '#기록', postType: 'RECORD'),
  expense(label: '#소비', postType: 'EXPENSE');

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

String _settlementDisplayStatusLabel(String status) {
  return switch (status) {
    'IN_PROGRESS' => '진행중',
    'COMPLETED' => '완료',
    _ => '미시작',
  };
}

const String _expenseLockedMessage = '정산 완료 후에는 소비를 추가할 수 없어요.';
const String _expensePostLockedMessage = '정산 완료 후에는 소비 기록을 변경할 수 없어요.';

String _roleLabel(String role) {
  return role == 'LEADER' ? '방장' : '동행자';
}

String _moneyLabel(TransactionSummary transaction) {
  return _moneyLabelFor(transaction.amount, transaction.currency);
}

String _moneyLabelFor(double amountValue, String currency) {
  final amount = _formatAmount(amountValue);
  return switch (currency) {
    'JPY' => '¥$amount',
    'KRW' => '₩$amount',
    'USD' => '\$$amount',
    _ => '$currency $amount',
  };
}

String _participantName(
  List<TripParticipant> participants,
  int participantId,
  String fallbackName,
) {
  if (fallbackName.isNotEmpty) return fallbackName;
  for (final participant in participants) {
    if (participant.id == participantId) return participant.displayName;
  }
  return '참여자 $participantId';
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
