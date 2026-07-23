import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/post/service/post_service.dart';
import 'package:togethertrip/features/transaction/service/transaction_service.dart';
import 'package:togethertrip/features/trip/screen/trip_detail_screen.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

void main() {
  testWidgets('정산 완료 여행은 소비 등록 진입을 막고 기록 작성은 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'SETTLED'),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('정산 완료 후에는 소비를 추가할 수 없어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('createExpenseOption')), findsOneWidget);

    await tester.tap(find.text('소비'));
    await tester.pumpAndSettle();
    expect(find.text('소비 등록'), findsNothing);

    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('기록 작성'), findsOneWidget);
  });

  testWidgets('정산 완료 여행의 소비 게시글은 수정 삭제 액션을 비활성화한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'SETTLED'),
          postService: _FakePostService(posts: [_expensePost()]),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();

    expect(find.text('정산 완료 후에는 소비 기록을 변경할 수 없어요.'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('postEditAction')))
          .enabled,
      false,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('postDeleteAction')))
          .enabled,
      false,
    );
  });

  testWidgets('정산 완료 여행의 일반 기록은 수정 삭제 액션을 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'SETTLED'),
          postService: _FakePostService(posts: [_recordPost()]),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();

    expect(find.text('정산 완료 후에는 소비 기록을 변경할 수 없어요.'), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('postEditAction')))
          .enabled,
      true,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('postDeleteAction')))
          .enabled,
      true,
    );
  });

  testWidgets('소비 정보는 피드 로딩이 아니라 돈 버튼 클릭 시 조회한다', (tester) async {
    final transactionService = _FakeTransactionService();

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(posts: [_expensePost()]),
          transactionService: transactionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(transactionService.getTransactionCallCount, 0);
    expect(find.text('소비 정보'), findsOneWidget);

    await tester.tap(find.text('소비 정보'));
    await tester.pumpAndSettle();

    expect(transactionService.getTransactionCallCount, 1);
    expect(find.text('소비 정보'), findsWidgets);
    expect(find.text('결제자'), findsOneWidget);
    expect(find.text('부담자'), findsOneWidget);
  });

  testWidgets('소비 게시글 수정은 소비 수정 폼으로 진입한다', (tester) async {
    final postService = _FakePostService(posts: [_expensePost()]);
    final transactionService = _FakeTransactionService();

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: postService,
          transactionService: transactionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('postEditAction')));
    await tester.pumpAndSettle();

    expect(find.text('소비 수정'), findsOneWidget);
    expect(find.text('지출 정보'), findsOneWidget);
    expect(transactionService.getTransactionCallCount, 1);
  });

  testWidgets('소비 게시글 수정은 통합 API 한 번으로 저장한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final postService = _FakePostService(posts: [_expensePost()]);
    final transactionService = _FakeTransactionService();

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: postService,
          transactionService: transactionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('postEditAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveExpenseButton')));
    await tester.pumpAndSettle();

    expect(postService.updateExpensePostCallCount, 1);
    expect(postService.updatePostCallCount, 0);
    expect(transactionService.updateTransactionCallCount, 0);
  });

  testWidgets('내 참여자 ID를 알 수 없으면 정산 화면 진입을 차단한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(
            settlementStatus: 'NOT_STARTED',
            failMyParticipant: true,
          ),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('정산 미시작'));
    await tester.pump();

    expect(find.text('내 여행 참여자 정보를 불러오지 못했습니다. 다시 시도해주세요.'), findsOneWidget);
  });

  testWidgets('Recap을 만들 수 없는 여행은 Recap CTA를 숨긴다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(
            settlementStatus: 'NOT_STARTED',
            recapStatus: const TripRecapStatus(
              available: false,
              status: TripRecapStatusValue.none,
              recapId: null,
              style: null,
            ),
          ),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지난 여행 Recap 만들기'), findsNothing);
    expect(find.text('지난 여행 Recap 보기'), findsNothing);
  });

  testWidgets('Recap 생성 가능 여행은 스타일 선택 후 생성 요청을 보낸다', (tester) async {
    final tripService = _FakeTripService(
      settlementStatus: 'SETTLED',
      recapStatus: const TripRecapStatus(
        available: true,
        status: TripRecapStatusValue.none,
        recapId: null,
        style: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: tripService,
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('지난 여행 Recap 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recapStylePHOTO')));
    await tester.pumpAndSettle();

    expect(tripService.createdStyles, [TripRecapStyle.photo]);
    expect(find.text('Recap 생성 중'), findsOneWidget);
  });

  testWidgets('실패한 Recap은 스타일 재선택 후 retry 요청을 보낸다', (tester) async {
    final tripService = _FakeTripService(
      settlementStatus: 'SETTLED',
      recapStatus: const TripRecapStatus(
        available: true,
        status: TripRecapStatusValue.failed,
        recapId: 100,
        style: TripRecapStyle.photo,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: tripService,
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recap 다시 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recapStyleILLUSTRATION')));
    await tester.pumpAndSettle();

    expect(tripService.retriedStyles, [TripRecapStyle.illustration]);
    expect(find.text('Recap 생성 중'), findsOneWidget);
  });

  testWidgets('생성 중인 Recap은 중복 생성 요청을 보내지 않는다', (tester) async {
    final tripService = _FakeTripService(
      settlementStatus: 'SETTLED',
      recapStatus: const TripRecapStatus(
        available: true,
        status: TripRecapStatusValue.creating,
        recapId: 100,
        style: TripRecapStyle.photo,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: tripService,
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recap 생성 중'));
    await tester.pumpAndSettle();

    expect(tripService.createdStyles, isEmpty);
    expect(tripService.retriedStyles, isEmpty);
  });
}

class _FakeTripService extends TripService {
  final String settlementStatus;
  final bool failMyParticipant;
  TripRecapStatus recapStatus;
  final createdStyles = <TripRecapStyle>[];
  final retriedStyles = <TripRecapStyle>[];

  _FakeTripService({
    required this.settlementStatus,
    this.failMyParticipant = false,
    TripRecapStatus? recapStatus,
  }) : recapStatus =
           recapStatus ??
           const TripRecapStatus(
             available: false,
             status: TripRecapStatusValue.none,
             recapId: null,
             style: null,
           );

  @override
  Future<TripDetail> getTrip(int tripId) async {
    return TripDetail(
      id: tripId,
      ownerUserId: 1,
      title: '오사카 여행',
      defaultCurrency: 'JPY',
      exchangeRateBaseDate: null,
      startDate: '2026-06-01',
      endDate: '2026-07-05',
      tripStatus: 'PLANNED',
      settlementStatus: settlementStatus,
      settledAt: settlementStatus == 'SETTLED' ? '2026-06-19T00:00:00Z' : null,
      countries: const [],
      participants: const [
        TripParticipant(
          id: 100,
          userId: 1,
          displayName: '재완',
          profileImageUrl: null,
          participantRole: 'LEADER',
          participantStatus: 'ACTIVE',
          joinedAt: '2026-06-01T00:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    return const UserProfile(
      id: 1,
      nickname: '재완',
      gender: null,
      birthDate: null,
      profileImageUrl: null,
      phoneNumberMasked: null,
      phoneVerifiedAt: null,
      phoneVerified: true,
    );
  }

  @override
  Future<TripParticipant> getMyTripParticipant(int tripId) async {
    if (failMyParticipant) {
      throw Exception('participant lookup failed');
    }
    return const TripParticipant(
      id: 100,
      userId: 1,
      displayName: '재완',
      profileImageUrl: null,
      participantRole: 'LEADER',
      participantStatus: 'ACTIVE',
      joinedAt: '2026-06-01T00:00:00Z',
    );
  }

  @override
  Future<TripRecapStatus> getRecapStatus(int tripId) async => recapStatus;

  @override
  Future<TripRecapCreateResult> createRecap(
    int tripId,
    TripRecapStyle style,
  ) async {
    createdStyles.add(style);
    recapStatus = TripRecapStatus(
      available: true,
      status: TripRecapStatusValue.creating,
      recapId: 100,
      style: style,
    );
    return const TripRecapCreateResult(
      recapId: 100,
      status: TripRecapStatusValue.creating,
    );
  }

  @override
  Future<TripRecapCreateResult> retryRecap(
    int tripId,
    TripRecapStyle style,
  ) async {
    retriedStyles.add(style);
    recapStatus = TripRecapStatus(
      available: true,
      status: TripRecapStatusValue.creating,
      recapId: 100,
      style: style,
    );
    return const TripRecapCreateResult(
      recapId: 100,
      status: TripRecapStatusValue.creating,
    );
  }
}

class _FakePostService extends PostService {
  final List<PostSummary> posts;
  int updatePostCallCount = 0;
  int updateExpensePostCallCount = 0;

  _FakePostService({required this.posts});

  @override
  Future<PostListPage> getPosts(
    int tripId, {
    String? postType,
    String? cursor,
    int size = 20,
  }) async {
    final filtered = postType == null
        ? posts
        : posts.where((post) => post.postType == postType).toList();
    return PostListPage(
      items: filtered,
      size: filtered.length,
      nextCursor: null,
      hasNext: false,
    );
  }

  @override
  Future<PostDetail> getPost(int tripId, int postId) async {
    final post = posts.firstWhere((item) => item.id == postId);
    return PostDetail(
      id: post.id,
      tripId: post.tripId,
      transactionId: post.transactionId,
      authorParticipantId: post.authorParticipantId,
      authorDisplayName: post.authorDisplayName,
      postType: post.postType,
      title: post.title,
      category: post.category,
      content: post.contentPreview,
      occurredAt: post.occurredAt,
      placeName: post.placeName,
      latitude: post.latitude,
      longitude: post.longitude,
      commentCount: post.commentCount,
      attachments: post.attachments,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
    );
  }

  @override
  Future<PostDetail> updatePost(
    int tripId,
    int postId,
    PostFormInput input,
  ) async {
    updatePostCallCount += 1;
    final post = await getPost(tripId, postId);
    return PostDetail(
      id: post.id,
      tripId: post.tripId,
      transactionId: post.transactionId,
      authorParticipantId: post.authorParticipantId,
      authorDisplayName: post.authorDisplayName,
      postType: post.postType,
      title: input.title,
      category: input.category,
      content: input.content,
      occurredAt: input.occurredAt,
      placeName: input.placeName,
      latitude: input.latitude,
      longitude: input.longitude,
      commentCount: post.commentCount,
      attachments: post.attachments,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
    );
  }

  @override
  Future<CreateExpensePostResult> updateExpensePost(
    int tripId,
    int postId,
    ExpensePostFormInput input,
  ) async {
    updateExpensePostCallCount += 1;
    final original = await getPost(tripId, postId);
    final post = PostDetail(
      id: original.id,
      tripId: original.tripId,
      transactionId: original.transactionId,
      authorParticipantId: original.authorParticipantId,
      authorDisplayName: original.authorDisplayName,
      postType: original.postType,
      title: input.postInput.title,
      category: input.postInput.category,
      content: input.postInput.content,
      occurredAt: input.postInput.occurredAt,
      placeName: input.postInput.placeName,
      latitude: input.postInput.latitude,
      longitude: input.postInput.longitude,
      commentCount: original.commentCount,
      attachments: original.attachments,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    );
    return CreateExpensePostResult(
      post: post,
      transaction: TransactionDetail(
        summary: TransactionSummary(
          id: post.transactionId ?? 200,
          tripId: tripId,
          transactionType: input.transactionInput.transactionType,
          amount: input.transactionInput.amount,
          currency: input.transactionInput.currency,
          exchangeRate: 9.5,
          baseCurrency: 'KRW',
          baseAmount: input.transactionInput.amount * 9.5,
          category: input.transactionInput.category,
          occurredAt: input.transactionInput.occurredAt,
          status: 'ACTIVE',
          createdByUserId: 1,
          createdAt: null,
          updatedAt: null,
        ),
        payments: const [],
        shares: const [],
      ),
    );
  }
}

class _FakeTransactionService extends TransactionService {
  int getTransactionCallCount = 0;
  int updateTransactionCallCount = 0;

  @override
  Future<TransactionDetail> getTransaction(
    int tripId,
    int transactionId,
  ) async {
    getTransactionCallCount += 1;
    return TransactionDetail(
      summary: TransactionSummary(
        id: 200,
        tripId: 10,
        transactionType: 'EXPENSE',
        amount: 12000,
        currency: 'JPY',
        exchangeRate: 9.5,
        baseCurrency: 'KRW',
        baseAmount: 114000,
        category: '식비',
        occurredAt: '2026-06-09T03:00:00Z',
        status: 'ACTIVE',
        createdByUserId: 1,
        createdAt: null,
        updatedAt: null,
      ),
      payments: const [
        TransactionPayment(
          id: 1,
          participantId: 100,
          participantDisplayName: '재완',
          amount: 12000,
        ),
      ],
      shares: const [
        TransactionShare(
          id: 2,
          participantId: 100,
          participantDisplayName: '재완',
          shareAmount: 12000,
          shareRatio: 1,
        ),
      ],
    );
  }

  @override
  Future<TransactionDetail> updateTransaction(
    int tripId,
    int transactionId,
    TransactionFormInput input,
  ) async {
    updateTransactionCallCount += 1;
    return getTransaction(tripId, transactionId);
  }
}

PostSummary _recordPost() {
  return _post(id: 1, transactionId: null, postType: 'RECORD', title: '첫날 기록');
}

PostSummary _expensePost() {
  return _post(id: 2, transactionId: 200, postType: 'EXPENSE', title: '라멘');
}

PostSummary _post({
  required int id,
  required int? transactionId,
  required String postType,
  required String title,
}) {
  return PostSummary(
    id: id,
    tripId: 10,
    transactionId: transactionId,
    authorParticipantId: 100,
    authorDisplayName: '재완',
    postType: postType,
    title: title,
    category: '식비',
    contentPreview: '내용',
    occurredAt: '2026-06-09T03:00:00Z',
    placeName: null,
    latitude: null,
    longitude: null,
    commentCount: 0,
    attachments: const [],
    createdAt: '2026-06-09T03:00:00Z',
    updatedAt: '2026-06-09T03:00:00Z',
  );
}
