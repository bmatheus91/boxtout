import 'package:customer/api/firestore_api.dart';
import 'package:customer/app/app.locator.dart';
import 'package:customer/app/app.logger.dart';
import 'package:customer/app/app.router.dart';
import 'package:customer/constants/app_strings.dart';
import 'package:customer/models/application_models.dart';
import 'package:customer/services/user_service.dart';
import 'package:stacked/stacked.dart';
import 'package:places_service/places_service.dart';
import 'package:stacked_services/stacked_services.dart';

import 'address_selection_view.form.dart';

class AddressSelectionViewModel extends FormViewModel {
  final log = getLogger('AddressSelectionViewModel');

  final _placesService = locator<PlacesService>();
  final _dialogService = locator<DialogService>();
  final _firestoreApi = locator<FirestoreApi>();
  final _navigationService = locator<NavigationService>();
  final _userService = locator<UserService>();

  List<PlacesAutoCompleteResult> _autoCompleteResults = [];
  PlacesAutoCompleteResult? _selectedResult;

  bool get hasSelectedPlace => _selectedResult != null;

  List<PlacesAutoCompleteResult> get autoCompleteResults =>
      _autoCompleteResults;

  bool get hasAutoCompleteResults => _autoCompleteResults.isNotEmpty;

  @override
  void setFormStatus() {
    _getAutoCompleteResults();
  }

  Future<void> _getAutoCompleteResults() async {
    if (addressValue != null) {
      final placesResults = await _placesService.getAutoComplete(addressValue!);

      if (placesResults != null) {
        _autoCompleteResults = placesResults;
        notifyListeners();
      }
    }
  }

  /// Gets the details from the Places Api and saves it to the backend
  Future<void> selectAddressSuggestion({
    PlacesAutoCompleteResult? autoCompleteResult,
  }) async {
    PlacesAutoCompleteResult selectedResult =
        autoCompleteResult ?? _selectedResult!;

    log.i('Selected $autoCompleteResult as the suggestion');

    if (selectedResult.placeId == null) {
      _dialogService.showDialog(
        title: InvalidAutoCompleteDialogTitle,
        description: InvalidAutoCompleteDialogDescription,
      );
    } else {
      setBusy(true);

      final placeDetails =
          await _placesService.getPlaceDetails(selectedResult.placeId ?? '');
      log.v('Place Details: $placeDetails');

      final address = Address(
        placeId: placeDetails.placeId!,
        lattitude: placeDetails.lat ?? -1,
        longitute: placeDetails.lng ?? -1,
        city: placeDetails.city,
        postalCode: placeDetails.zip,
        state: placeDetails.state,
        street: placeDetails.streetLong ?? placeDetails.streetShort,
      );

      final saveSuccess = await _firestoreApi.saveAddress(
        address: address,
        user: _userService.currentUser,
      );

      if (!saveSuccess) {
        log.v('Address save failed. Notify user to try again.');
        _dialogService.showDialog(
          title: AddressSaveFailedDialogTitle,
          description: AddressSaveFailedDialogDescription,
        );
      } else {
        log.v(
            'Address has been saved! We\'re ready to show them some products!');
        _navigationService.clearStackAndShow(Routes.homeView);
      }

      setBusy(false);
    }
  }

  void setSelectedSuggestion(PlacesAutoCompleteResult autoCompleteResult) {
    log.i('autoCompleteResult:$autoCompleteResult');
    _selectedResult = autoCompleteResult;

    _autoCompleteResults.clear();

    notifyListeners();
  }
}
