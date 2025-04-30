enum Events {
  takeItem,
  returnItem,
  checkItem,
  submitDamageItem,
  confirmTakeover,
  getUser,
  updateItem,
  acceptRequest,
  declineRequest,
  deactivateRequest,
  approveRequest,
  reserveItem,
  cancelReservation,
  updateUser
}

extension EventsExtension on Events {
  String get name {
    switch (this) {
      case Events.takeItem:
        return 'take_item';
      case Events.returnItem:
        return 'return_item';
      case Events.checkItem:
        return 'check_item';
      case Events.submitDamageItem:
        return 'submit_damage_item';
      case Events.confirmTakeover:
        return 'confirm_takeover';
      case Events.getUser:
        return 'get_user';
      case Events.updateItem:
        return 'update_item';
      case Events.acceptRequest:
        return 'accept_request';
      case Events.declineRequest:
        return 'decline_request';
      case Events.deactivateRequest:
        return 'deactivate_request';
      case Events.approveRequest:
        return 'approve_request';
      case Events.reserveItem:
        return 'reserve_item';
      case Events.cancelReservation:
        return 'cancel_reservation';
      case Events.updateUser:
       return 'update_user';
    }
  }
}
