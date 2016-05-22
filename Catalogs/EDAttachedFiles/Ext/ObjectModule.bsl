#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	// It is called out directly before the object is recorded in the database
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If EDStatus <> Ref.EDStatus Then
		If EDKind = Enums.EDKinds.CancellationOffer AND EDStatus <> Ref.EDStatus Then
			EDOwnerParameters = CommonUse.ObjectAttributesValues(ElectronicDocumentOwner,
				"EDStatus, EDDirection");
			If EDOwnerParameters.EDStatus = Enums.EDStatuses.CancellationOfferReceived
				OR EDOwnerParameters.EDStatus = Enums.EDStatuses.CancellationOfferCreated Then
				If (EDStatus = Enums.EDStatuses.ConfirmationSent
						OR EDStatus = Enums.EDStatuses.ConfirmationReceived) Then
					ElectronicDocumentsServiceCallServer.SetEDStatus(ElectronicDocumentOwner,
						Enums.EDStatuses.Canceled);
				ElsIf (EDStatus = Enums.EDStatuses.RejectedByReceiver
						OR EDStatus = Enums.EDStatuses.Rejected) Then
					ExchangeSettings = ElectronicDocumentsService.EDExchangeSettings(ElectronicDocumentOwner);
					StatusesArray = ElectronicDocumentsService.ReturnEDStatusesArray(ExchangeSettings);
					NewEDStatus = StatusesArray[StatusesArray.UBound()];
					ParametersStructure = New Structure("EDStatus, RejectionReason", NewEDStatus, "");
					ElectronicDocumentsServiceCallServer.ChangeByRefAttachedFile(ElectronicDocumentOwner,
						ParametersStructure, False);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndIf
