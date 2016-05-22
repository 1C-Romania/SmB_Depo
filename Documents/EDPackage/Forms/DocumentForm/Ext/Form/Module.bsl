
#Region CommandsActionsForms

&AtClient
Procedure UnpackEDPackage(Command)
	
	ArrayPED = New Array;
	ArrayPED.Add(Object.Ref);
	ElectronicDocumentsServiceClient.UnpackEDPackagesArray(ArrayPED);
	Read();
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure SelectionElectronicDocuments(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ElectronicDocumentsObjectOwner" Then
		ShowValue(,Item.CurrentData.OwnerObject);
		
	ElsIf TypeOf(Item.CurrentData.ElectronicDocument) = Type("CatalogRef.EDAttachedFiles") Then
		StandardProcessing = False;
		ElectronicDocumentsServiceClient.OpenEDForViewing(Item.CurrentData.ElectronicDocument);
	
	Else
		ShowValue(,Item.CurrentData.ElectronicDocument);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	Items.CommandUnpackEDPackage.Visible = Object.PackageStatus = Enums.EDPackagesStatuses.ToUnpacking;
	Items.CounterpartyResourceAddress.Visible   = Not Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource;
	Items.CompanyResourceAddress.Visible   = Not Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
		AND ValueIsFilled(Object.Sender)
		AND Not Find(Object.Sender, "2AL") > 0 Then
		
		Cancel = True;
	EndIf;
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(Object.EDFSetup, "BankApplication");
	If Object.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource
		AND (AgreementAttributes.BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
			OR AgreementAttributes.BankApplication = Enums.BankApplications.iBank2) Then
		
		Items.FormDocumentEDPackageSavePackageOnDrive.Visible = False;
	EndIf;
	
	PackageStatus = Object.PackageStatus;
	FillPackageStatusesChoiceList();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CurrentObject.PackageStatus = PackageStatus Then
		CurrentObject.PackageStatus = PackageStatus;
	EndIf;
	
	PackageStatus = Object.PackageStatus;
	FillPackageStatusesChoiceList();

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillPackageStatusesChoiceList()
	
	If Object.Direction = Enums.EDDirections.Incoming Then
		Items.PackageStatus.ChoiceList.LoadValues(StatusListIncoming());
	Else
		Items.PackageStatus.ChoiceList.LoadValues(StatusListOutgoing());
	EndIf;
	
EndProcedure

&AtServerNoContext
Function StatusListIncoming()
	
	StatusesArray = New Array;
	StatusesArray.Add(Enums.EDPackagesStatuses.ToUnpacking);
	StatusesArray.Add(Enums.EDPackagesStatuses.Unpacked);
	StatusesArray.Add(Enums.EDPackagesStatuses.UnpackedDocumentsNotProcessed);
	StatusesArray.Add(Enums.EDPackagesStatuses.Unknown);
	
	Return StatusesArray;
	
EndFunction

&AtServerNoContext
Function StatusListOutgoing()
	
	StatusesArray = New Array;
	StatusesArray.Add(Enums.EDPackagesStatuses.Delivered);
	StatusesArray.Add(Enums.EDPackagesStatuses.Canceled);
	StatusesArray.Add(Enums.EDPackagesStatuses.Sent);
	StatusesArray.Add(Enums.EDPackagesStatuses.PreparedToSending);
	
	Return StatusesArray;
	
EndFunction

#EndRegion