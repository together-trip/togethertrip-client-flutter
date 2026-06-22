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
}

class _FakeTripService extends TripService {
  final String settlementStatus;

  _FakeTripService({required this.settlementStatus});

  @override
  Future<TripDetail> getTrip(int tripId) async {
    return TripDetail(
      id: tripId,
      ownerUserId: 1,
      title: '오사카 여행',
      defaultCurrency: 'JPY',
      exchangeRateBaseDate: null,
      startDate: '2026-07-01',
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
}

class _FakePostService extends PostService {
  final List<PostSummary> posts;

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
}

class _FakeTransactionService extends TransactionService {
  @override
  Future<TransactionDetail> getTransaction(
    int tripId,
    int transactionId,
  ) async {
    return const TransactionDetail(
      summary: TransactionSummary(
        id: 200,
        tripId: 10,
        transactionType: 'EXPENSE',
        amount: 12000,
        currency: 'JPY',
        exchangeRate: 9.5,
        baseCurrency: 'KRW',
        baseAmount: 114000,
        status: 'ACTIVE',
        createdByUserId: 1,
        createdAt: null,
        updatedAt: null,
      ),
      payments: [],
      shares: [],
    );
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
