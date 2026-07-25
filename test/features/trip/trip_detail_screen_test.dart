import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/post/service/post_service.dart';
import 'package:togethertrip/features/post/widget/authenticated_attachment_image.dart';
import 'package:togethertrip/features/moderation/model/moderation_models.dart';
import 'package:togethertrip/features/moderation/service/moderation_service.dart';
import 'package:togethertrip/features/transaction/service/transaction_service.dart';
import 'package:togethertrip/features/trip/screen/trip_detail_screen.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

void main() {
  testWidgets('여행 상세는 기존 앱바, 필터, 정산, 피드, 추가 버튼 구조를 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(posts: [_recordPost()]),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오사카 여행'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('#기록'), findsOneWidget);
    expect(find.text('#소비'), findsOneWidget);
    expect(find.text('정산 미시작'), findsOneWidget);
    expect(find.text('정산 보기'), findsOneWidget);
    expect(find.text('첫날 기록'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('참여자 메뉴는 임시 참여자를 제외한 다른 사용자의 신고와 차단을 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
          moderationService: _EmptyModerationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('여행 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('participantMenu-200')));
    await tester.pumpAndSettle();

    expect(find.text('사용자 신고'), findsOneWidget);
    expect(find.text('사용자 차단'), findsOneWidget);
  });

  testWidgets('차단 사용자의 일반 기록은 숨기고 소비·정산 기록은 보존 안내와 함께 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 11,
                transactionId: null,
                postType: 'RECORD',
                title: '숨길 기록',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
              _post(
                id: 12,
                transactionId: 201,
                postType: 'EXPENSE',
                title: '보존할 지출',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: _FakeModerationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('숨길 기록'), findsNothing);
    expect(find.text('보존할 지출'), findsOneWidget);
    expect(find.text('차단한 사용자의 일반 기록은 표시되지 않습니다.'), findsOneWidget);
    expect(find.textContaining('지출·정산 정보는 금액 계산을 위해 표시'), findsOneWidget);
  });

  testWidgets('서버가 차단 사용자의 기록을 제외해도 차단 목록 기준 숨김 안내를 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
          moderationService: _FakeModerationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('차단한 사용자의 일반 기록은 표시되지 않습니다.'), findsOneWidget);
  });

  testWidgets('피드 첨부 이미지는 상대 API 경로를 인증 image loader로 조회한다', (tester) async {
    final loader = _RecordingAttachmentLoader();
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 1,
                transactionId: null,
                postType: 'RECORD',
                title: '첨부 기록',
                attachments: const [
                  PostAttachment(
                    id: 30,
                    attachmentType: 'IMAGE',
                    fileUrl: '/api/trips/10/posts/1/attachments/30',
                    thumbnailUrl: null,
                    fileSize: null,
                    mimeType: 'image/png',
                    sortOrder: 0,
                  ),
                ],
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: _EmptyModerationService(),
          attachmentImageLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loader.paths, ['/api/trips/10/posts/1/attachments/30']);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('썸네일 없는 동영상은 원본 MP4를 조회하지 않고 전용 placeholder를 표시한다', (
    tester,
  ) async {
    final loader = _RecordingAttachmentLoader();
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 1,
                transactionId: null,
                postType: 'RECORD',
                title: '동영상 기록',
                attachments: const [
                  PostAttachment(
                    id: 31,
                    attachmentType: 'VIDEO',
                    fileUrl: '/api/trips/10/posts/1/attachments/31',
                    thumbnailUrl: null,
                    fileSize: null,
                    mimeType: 'video/mp4',
                    sortOrder: 0,
                  ),
                ],
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: _EmptyModerationService(),
          attachmentImageLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loader.paths, isEmpty);
    expect(
      find.byKey(const ValueKey('videoAttachmentPlaceholder')),
      findsOneWidget,
    );
    expect(find.text('동영상 첨부'), findsOneWidget);
  });

  testWidgets('동영상 썸네일이 있으면 원본 대신 썸네일 이미지만 조회한다', (tester) async {
    final loader = _RecordingAttachmentLoader();
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 1,
                transactionId: null,
                postType: 'RECORD',
                title: '썸네일 동영상 기록',
                attachments: const [
                  PostAttachment(
                    id: 31,
                    attachmentType: 'VIDEO',
                    fileUrl: '/api/trips/10/posts/1/attachments/31',
                    thumbnailUrl: '/api/trips/10/posts/1/attachments/32',
                    fileSize: null,
                    mimeType: 'video/mp4',
                    sortOrder: 0,
                  ),
                ],
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: _EmptyModerationService(),
          attachmentImageLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loader.paths, ['/api/trips/10/posts/1/attachments/32']);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('외부 차단 해제 version 변경 시 보존된 여행 상세이 차단 목록을 다시 불러온다', (
    tester,
  ) async {
    final service = _TransitionModerationService(
      blockedUsers: const [
        BlockedUser(blockedUserId: 2, displayName: '민수', blockedAt: null),
      ],
    );
    const screenKey = ValueKey('moderationRefreshTripDetail');

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          key: screenKey,
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
          moderationService: service,
          moderationVersion: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('차단한 사용자의 일반 기록은 표시되지 않습니다.'), findsOneWidget);

    service.blockedUsers.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          key: screenKey,
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(posts: const []),
          transactionService: _FakeTransactionService(),
          moderationService: service,
          moderationVersion: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('차단한 사용자의 일반 기록은 표시되지 않습니다.'), findsNothing);
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
  });

  testWidgets('타인 게시글 신고는 대상과 사유를 한 번만 전송한다', (tester) async {
    _setLargeSurface(tester);
    final service = _TransitionModerationService();
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 11,
                transactionId: null,
                postType: 'RECORD',
                title: '신고할 기록',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reportPostAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reportReason-SPAM')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reportSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('reportSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmReportButton')));
    await tester.pumpAndSettle();

    expect(service.reports, hasLength(1));
    expect(service.reports.single.targetType, ReportTargetType.post);
    expect(service.reports.single.targetId, 11);
  });

  testWidgets('작성자 차단 성공 직후 일반 기록을 숨기고 중복 요청을 막는다', (tester) async {
    final service = _TransitionModerationService();
    service.blockCompleter = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 11,
                transactionId: null,
                postType: 'RECORD',
                title: '차단할 기록',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openPostBlockAction(tester);
    await tester.tap(find.byKey(const ValueKey('confirmBlockUserButton')));
    await tester.pump();
    await _openPostBlockAction(tester);
    expect(find.byKey(const ValueKey('confirmBlockUserButton')), findsNothing);
    expect(service.blockCalls, [2]);

    service.blockCompleter!.complete();
    await tester.pumpAndSettle();
    expect(find.text('차단할 기록'), findsNothing);
    expect(find.text('차단한 사용자의 일반 기록은 표시되지 않습니다.'), findsOneWidget);
  });

  testWidgets('작성자 차단 실패 시 기록을 유지하고 오류를 표시한다', (tester) async {
    final service = _TransitionModerationService()..failBlock = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 11,
                transactionId: null,
                postType: 'RECORD',
                title: '유지할 기록',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openPostBlockAction(tester);
    await tester.tap(find.byKey(const ValueKey('confirmBlockUserButton')));
    await tester.pumpAndSettle();

    expect(find.text('유지할 기록'), findsOneWidget);
    expect(find.text('차단 요청 실패'), findsOneWidget);
  });

  testWidgets('차단 작성자의 소비 메뉴는 차단 해제를 제공하고 성공 시 보존 안내를 제거한다', (tester) async {
    final service = _TransitionModerationService(
      blockedUsers: const [
        BlockedUser(blockedUserId: 2, displayName: '민수', blockedAt: null),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 12,
                transactionId: 201,
                postType: 'EXPENSE',
                title: '보존 지출',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('unblockPostAuthorAction')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('unblockPostAuthorAction')));
    await tester.pumpAndSettle();

    expect(service.unblockCalls, [2]);
    expect(find.text('보존 지출'), findsOneWidget);
    expect(find.textContaining('지출·정산 정보는 금액 계산을 위해 표시'), findsNothing);
  });

  testWidgets('작성자 차단 해제 실패 시 소비 보존 안내를 유지한다', (tester) async {
    final service = _TransitionModerationService(
      blockedUsers: const [
        BlockedUser(blockedUserId: 2, displayName: '민수', blockedAt: null),
      ],
    )..failUnblock = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 12,
                transactionId: 201,
                postType: 'EXPENSE',
                title: '보존 지출',
                authorParticipantId: 200,
                authorUserId: 2,
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unblockPostAuthorAction')));
    await tester.pumpAndSettle();

    expect(find.text('차단 해제 실패'), findsOneWidget);
    expect(find.textContaining('지출·정산 정보는 금액 계산을 위해 표시'), findsOneWidget);
  });

  testWidgets('댓글 신고 진입은 comment target을 전송한다', (tester) async {
    _setLargeSurface(tester);
    final service = _TransitionModerationService();
    final postService = _FakePostService(
      posts: [
        _post(
          id: 1,
          transactionId: null,
          postType: 'RECORD',
          title: '기록',
          commentCount: 1,
        ),
      ],
      comments: [_otherComment()],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: postService,
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('댓글 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commentMenu-31')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reportCommentAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reportReason-PRIVACY')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reportSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('reportSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmReportButton')));
    await tester.pumpAndSettle();

    expect(service.reports, hasLength(1));
    expect(service.reports.single.targetType, ReportTargetType.comment);
    expect(service.reports.single.targetId, 31);
  });

  testWidgets('차단 댓글은 내용을 숨기되 작성자 차단 해제 메뉴로 즉시 복구한다', (tester) async {
    final service = _TransitionModerationService(
      blockedUsers: const [
        BlockedUser(blockedUserId: 2, displayName: '민수', blockedAt: null),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 1,
                transactionId: null,
                postType: 'RECORD',
                title: '기록',
                commentCount: 1,
              ),
            ],
            comments: [_otherComment()],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('댓글 1'));
    await tester.pumpAndSettle();
    expect(find.text('숨겨진 댓글 원문'), findsNothing);
    expect(find.text('차단한 사용자의 댓글을 숨겼습니다.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('blockedCommentMenu-31')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('unblockCommentAuthorAction')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('unblockCommentAuthorAction')));
    await tester.pumpAndSettle();

    expect(service.unblockCalls, [2]);
    expect(find.text('숨겨진 댓글 원문'), findsOneWidget);
    expect(find.text('차단한 사용자의 일반 댓글은 표시되지 않습니다.'), findsNothing);
  });

  testWidgets('서버가 댓글을 제외해도 block list 기준 숨김 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          tripId: 10,
          tripService: _FakeTripService(settlementStatus: 'NOT_STARTED'),
          postService: _FakePostService(
            posts: [
              _post(
                id: 1,
                transactionId: null,
                postType: 'RECORD',
                title: '기록',
              ),
            ],
          ),
          transactionService: _FakeTransactionService(),
          moderationService: _FakeModerationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('댓글 0'));
    await tester.pumpAndSettle();
    expect(find.text('차단한 사용자의 일반 댓글은 표시되지 않습니다.'), findsOneWidget);
  });

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
    await tester.tap(find.byKey(const ValueKey('expenseNextButton')));
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

Future<void> _openPostBlockAction(WidgetTester tester) async {
  await tester.tap(find.byTooltip('게시글 메뉴'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('blockPostAuthorAction')));
  await tester.pumpAndSettle();
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
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
        TripParticipant(
          id: 200,
          userId: 2,
          displayName: '민수',
          profileImageUrl: null,
          participantRole: 'MEMBER',
          participantStatus: 'ACTIVE',
          joinedAt: '2026-06-01T00:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    return const UserProfile(id: 1, nickname: '재완', profileImageUrl: null);
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
  final List<PostComment> comments;
  int updatePostCallCount = 0;
  int updateExpensePostCallCount = 0;

  _FakePostService({required this.posts, this.comments = const []});

  @override
  Future<PostCommentListPage> getComments(
    int tripId,
    int postId, {
    String? cursor,
    int size = 30,
  }) async {
    return PostCommentListPage(
      items: comments,
      size: comments.length,
      nextCursor: null,
      hasNext: false,
    );
  }

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

PostComment _otherComment() {
  return const PostComment(
    id: 31,
    postId: 1,
    authorParticipantId: 200,
    authorUserId: 2,
    authorDisplayName: '민수',
    content: '숨겨진 댓글 원문',
    commentDepth: 0,
    createdAt: null,
    updatedAt: null,
  );
}

PostSummary _post({
  required int id,
  required int? transactionId,
  required String postType,
  required String title,
  int authorParticipantId = 100,
  int? authorUserId,
  int commentCount = 0,
  List<PostAttachment> attachments = const [],
}) {
  return PostSummary(
    id: id,
    tripId: 10,
    transactionId: transactionId,
    authorParticipantId: authorParticipantId,
    authorUserId: authorUserId,
    authorDisplayName: authorParticipantId == 100 ? '재완' : '민수',
    postType: postType,
    title: title,
    category: '식비',
    contentPreview: '내용',
    occurredAt: '2026-06-09T03:00:00Z',
    placeName: null,
    latitude: null,
    longitude: null,
    commentCount: commentCount,
    attachments: attachments,
    createdAt: '2026-06-09T03:00:00Z',
    updatedAt: '2026-06-09T03:00:00Z',
  );
}

class _FakeModerationService extends ModerationService {
  @override
  Future<List<BlockedUser>> getBlockedUsers() async => const [
    BlockedUser(blockedUserId: 2, displayName: '민수', blockedAt: null),
  ];
}

class _EmptyModerationService extends ModerationService {
  @override
  Future<List<BlockedUser>> getBlockedUsers() async => const [];
}

class _TransitionModerationService extends ModerationService {
  _TransitionModerationService({List<BlockedUser> blockedUsers = const []})
    : blockedUsers = [...blockedUsers];

  final List<BlockedUser> blockedUsers;
  final reports = <ReportRequest>[];
  final blockCalls = <int>[];
  final unblockCalls = <int>[];
  Completer<void>? blockCompleter;
  bool failBlock = false;
  bool failUnblock = false;

  @override
  Future<List<BlockedUser>> getBlockedUsers() async => [...blockedUsers];

  @override
  Future<ReportResult> createReport(int tripId, ReportRequest request) async {
    reports.add(request);
    return const ReportResult(id: 1, status: 'RECEIVED', createdAt: null);
  }

  @override
  Future<void> blockUser(int userId) async {
    blockCalls.add(userId);
    await blockCompleter?.future;
    if (failBlock) {
      throw const ApiException(statusCode: 500, message: '차단 요청 실패');
    }
    blockedUsers.add(
      BlockedUser(blockedUserId: userId, displayName: '민수', blockedAt: null),
    );
  }

  @override
  Future<void> unblockUser(int userId) async {
    unblockCalls.add(userId);
    if (failUnblock) {
      throw const ApiException(statusCode: 500, message: '차단 해제 실패');
    }
    blockedUsers.removeWhere((user) => user.blockedUserId == userId);
  }
}

class _RecordingAttachmentLoader extends AuthenticatedAttachmentImageLoader {
  final paths = <String>[];

  @override
  Future<Uint8List> load(String path) async {
    paths.add(path);
    return Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }
}
