import 'package:url_launcher/url_launcher.dart';

import '../../../core/env/env.dart';

enum PublicSitePage {
  privacyPolicy,
  termsOfService,
  communityPolicy,
  customerSupport,
  accountDeletion,
}

class PublicSiteLinks {
  final Map<PublicSitePage, Uri> _links;

  PublicSiteLinks({Map<PublicSitePage, Uri>? links})
    : _links =
          links ??
          {
            PublicSitePage.privacyPolicy: Uri.parse(Env.privacyPolicyUrl),
            PublicSitePage.termsOfService: Uri.parse(Env.termsOfServiceUrl),
            PublicSitePage.communityPolicy: Uri.parse(Env.communityPolicyUrl),
            PublicSitePage.customerSupport: Uri.parse(Env.customerSupportUrl),
            PublicSitePage.accountDeletion: Uri.parse(Env.accountDeletionUrl),
          };

  Uri get(PublicSitePage page) => _links[page]!;
}

abstract class ExternalLinkLauncher {
  Future<bool> open(Uri uri);
}

class UrlLauncherExternalLinkLauncher implements ExternalLinkLauncher {
  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
