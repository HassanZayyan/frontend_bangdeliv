import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/chatbot/application/chatbot_conversation_provider.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  test(
    'Nitip address guard is replaced with ready welcome after address becomes usable',
    () async {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_session(hasUsableAddress: false)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = chatbotConversationProvider('nitip');
      final notifier = container.read(provider.notifier);

      await notifier.bootstrap(
        serviceType: 'nitip',
        welcomeMessage:
            'Sebelum pesan Nitip, pilih alamat antar dulu supaya ongkir bisa dihitung.',
      );

      var state = container.read(provider);
      expect(state.messages, hasLength(1));
      expect(state.messages.single.text, startsWith('Sebelum pesan Nitip'));
      expect(
        state.messages.single.actionHints.single.type,
        ChatbotMessageActionType.openAddresses,
      );

      container
          .read(authSessionProvider.notifier)
          .syncProfile(_profile(hasUsableAddress: true));

      final changed = notifier.syncSavedAddressReadiness(
        serviceType: 'nitip',
        readyWelcomeMessage:
            'Halo! Saya BangBot untuk layanan Nitip. Tulis nama toko/resto dan barang yang ingin dibeli.',
      );

      state = container.read(provider);
      expect(changed, isTrue);
      expect(state.messages, hasLength(1));
      expect(state.messages.single.text, startsWith('Halo! Saya BangBot'));
      expect(
        state.messages.single.actionHints.map((hint) => hint.label),
        containsAll(<String>['Pilih Toko/Resto', 'Pilih Alamat Antar']),
      );
      expect(
        state.messages.single.actionHints.where(
          (hint) => hint.type == ChatbotMessageActionType.openAddresses,
        ),
        isEmpty,
      );
    },
  );

  test(
    'Nitip address readiness preserves started conversation and appends ready actions',
    () async {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_session(hasUsableAddress: false)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = chatbotConversationProvider('nitip');
      final notifier = container.read(provider.notifier);

      await notifier.bootstrap(
        serviceType: 'nitip',
        welcomeMessage:
            'Sebelum pesan Nitip, pilih alamat antar dulu supaya ongkir bisa dihitung.',
      );
      notifier.addLocalGuardResponse(
        rawMessage: 'Beli nasi goreng',
        serviceType: 'nitip',
        assistantMessage: 'Isi alamat antar dulu sebelum pesan Nitip.',
        actionHints: const <ChatbotMessageActionHint>[
          ChatbotMessageActionHint(
            type: ChatbotMessageActionType.openAddresses,
            label: 'Isi Alamat Saya',
          ),
        ],
      );

      container
          .read(authSessionProvider.notifier)
          .syncProfile(_profile(hasUsableAddress: true));

      final changed = notifier.syncSavedAddressReadiness(
        serviceType: 'nitip',
        readyWelcomeMessage:
            'Halo! Saya BangBot untuk layanan Nitip. Tulis nama toko/resto dan barang yang ingin dibeli.',
      );

      final state = container.read(provider);
      expect(changed, isTrue);
      expect(
        state.messages.map((message) => message.text),
        contains('Beli nasi goreng'),
      );
      expect(state.messages.last.text, startsWith('Alamat antar utama'));
      expect(
        state.messages.last.actionHints.map((hint) => hint.label),
        containsAll(<String>['Pilih Toko/Resto', 'Pilih Alamat Antar']),
      );
    },
  );
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() => _initialState;
}

AuthSessionState _session({required bool hasUsableAddress}) {
  return AuthSessionState.fromProfile(
    _profile(hasUsableAddress: hasUsableAddress),
  );
}

UserProfileModel _profile({required bool hasUsableAddress}) {
  return UserProfileModel(
    id: 7,
    name: 'Customer',
    phone: '08123456789',
    email: 'customer@example.com',
    avatar: null,
    avatarUrl: null,
    role: 'customer',
    driverProfile: null,
    stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
    addresses: hasUsableAddress
        ? const <SavedAddressModel>[
            SavedAddressModel(
              id: 11,
              label: 'Rumah',
              recipientName: 'Customer',
              phone: '08123456789',
              fullAddress: 'Jl. Sawunggaling III',
              detail: 'No. 7',
              latitude: -7.3305,
              longitude: 110.5084,
              isDefault: true,
            ),
          ]
        : const <SavedAddressModel>[],
  );
}
