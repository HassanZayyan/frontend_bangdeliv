import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/addresses/application/address_form_presenter.dart';

void main() {
  test('normalizeAddressLabel maps common labels to supported options', () {
    expect(AddressFormPresenter.normalizeAddressLabel('Rumah utama'), 'Rumah');
    expect(AddressFormPresenter.normalizeAddressLabel('Office'), 'Kantor');
    expect(
      AddressFormPresenter.normalizeAddressLabel('Kos dekat kampus'),
      'Lainnya',
    );
  });

  test(
    'isCoordinatePairValid rejects missing, out of range, and zero points',
    () {
      expect(AddressFormPresenter.isCoordinatePairValid(null, 110), isFalse);
      expect(AddressFormPresenter.isCoordinatePairValid(-91, 110), isFalse);
      expect(AddressFormPresenter.isCoordinatePairValid(-7, 181), isFalse);
      expect(AddressFormPresenter.isCoordinatePairValid(0, 0), isFalse);
      expect(AddressFormPresenter.isCoordinatePairValid(-7.33, 110.5), isTrue);
    },
  );
}
