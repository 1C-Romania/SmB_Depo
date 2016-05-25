&AtClient
Var ReaderData; // Data cache of magnetic card reader

#Region CommonUseProceduresAndFunctions

// Handles activation event of catalog items list row.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, DiscountCard, DiscountPercentByDiscountCard, Counterparty, ContactPerson", "CardOwner", Items.List.CurrentRow);
	SmallBusinessClient.DiscountCardsInformationPanelHandleListRowActivation(ThisForm, InfPanelParameters);
	
EndProcedure // HandleListStringActivation()

#EndRegion

#Region DynamicListEventHandlers

// Procedure - event handler OnActivateRow of dynamic list List.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
EndProcedure

#EndRegion

#Region DetailsEventsHandlersProcedures

// Procedure - event  handler OnChange of item FilterCardKind.
//
&AtClient
Procedure FilterCardKindOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DiscountCardsListFilterCardKind");
	// End StandardSubsystems.PerformanceEstimation
	
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", FilterCardKind, ValueIsFilled(FilterCardKind));

EndProcedure

// Procedure - event handler OnChange of item FilterOnlyNominal.
//
&AtClient
Procedure FilterOnlyNominalOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DiscountCardsListFilterCardKind");
	// End StandardSubsystems.PerformanceEstimation
	
	If FilterOnlyNominal Then
		List.Filter.Items.Clear();
		SmallBusinessClientServer.SetListFilterItem(List, "CardOwner", Parameters.Counterparty, True);
	Else
		List.Filter.Items.Clear();
		VL = New ValueList;
		VL.Add(Parameters.Counterparty);
		VL.Add(PredefinedValue("Catalog.Counterparties.EmptyRef"));
		
		// If a counterparty is not selected, show only anonymous cards.!!
		SmallBusinessClientServer.SetListFilterItem(List, "CardOwner", VL, True, DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

// Procedure - event  handler OnChange of item FilterBarcode.
//
&AtClient
Procedure FilterBarcodeOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DiscountCardsListFilterBarcode");
	// End StandardSubsystems.PerformanceEstimation
	
	SmallBusinessClientServer.SetListFilterItem(List, "CardCodeBarcode", FilterBarcode, ValueIsFilled(FilterBarcode), DataCompositionComparisonType.Contains);

EndProcedure

// Procedure - event handler OnChange of item FilterMagneticCode.
//
&AtClient
Procedure FilterMagneticCodeOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DiscountCardsListFilterMagneticCode");
	// End StandardSubsystems.PerformanceEstimation
	
	SmallBusinessClientServer.SetListFilterItem(List, "CardCodeMagnetic", FilterMagneticCode, ValueIsFilled(FilterMagneticCode), DataCompositionComparisonType.Contains);

EndProcedure

// Procedure - handler of clicking the SendEmailToCounterparty button.
//
&AtClient
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(CounterpartyInformationES) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Ref);
		StructureRecipient.Insert("Address", CounterpartyInformationES);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToCounterparty()

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationSimpCurrency = Constants.AccountingCurrency.Get();
	
	If ValueIsFilled(Parameters.Counterparty) Then
		Items.LabelCounterparty.Title = TrimAll(Parameters.Counterparty.Description);
	Else
		Items.LabelCounterparty.Title = "<Counterparty is not selected>";
		Items.FilterOnlyNominal.Visible = False;
	EndIf;
	
	// FilterByCounterparty
	List.Filter.Items.Clear();
	VL = New ValueList;
	If Not Parameters.Counterparty.IsEmpty() Then
		VL.Add(Parameters.Counterparty);
	EndIf;
	VL.Add(PredefinedValue("Catalog.Counterparties.EmptyRef"));
	
	// If a counterparty is not selected, show only anonymous cards.!!
	SmallBusinessClientServer.SetListFilterItem(List, "CardOwner", VL, True, DataCompositionComparisonType.InList);
	// End FilterByCounterparty
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	// End Peripherals	

EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

EndProcedure

// Procedure - event handler OnLoadDataFromSettingsAtServer.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Owner", FilterCardKind, ValueIsFilled(FilterCardKind));
	If FilterOnlyNominal Then
		List.Filter.Items.Clear();
		SmallBusinessClientServer.SetListFilterItem(List, "CardOwner", Parameters.Counterparty, True);
	Else
		// This branch is always executed in the procedure "OnCreateAtServer()" which gets called before this procedure.
	EndIf;
	// Filter by barcode and magnetic code can not be saved.
	SmallBusinessClientServer.SetListFilterItem(List, "CardCodeBarcode", FilterBarcode, ValueIsFilled(FilterBarcode), DataCompositionComparisonType.Contains);
	SmallBusinessClientServer.SetListFilterItem(List, "CardCodeMagnetic", FilterMagneticCode, ValueIsFilled(FilterMagneticCode), DataCompositionComparisonType.Contains);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,MagneticCardReader");
	// End Peripherals

EndProcedure

// Procedure - event  handler BeforeClose.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	SavedInSettingsDataModified = True;
	
EndProcedure

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode");
			HandleBarcodes(DiscountCardsClient.ConvertDataFromScannerIntoArray(Parameter));
			CurrentItem = Items.FilterBarcode;
		ElsIf EventName ="TracksData" Then
			// Processing the situation when magnetic card reader simulates clicking the Enter button after reading the magnetic card.
			CurDate = CurrentDate();
			
			CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode");
			HandleMagneticCardsReaderData(Parameter);
			CurrentItem = Items.FilterMagneticCode;
			
			// Processing the situation when magnetic card reader simulates clicking the Enter button after reading the magnetic card.
			// You can cut the newline character in the peripherals settings to read magnetic cards.
			While (CurrentDate() - CurDate) < 1 Do EndDo;
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

#EndRegion

#Region BarcodesAndShopEquipment

// Procedure processes barcode data transmitted from form notifications data processor.
//
&AtClient
Procedure HandleBarcodes(BarcodesData)
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	HandleReceivedCodeOnClient(BarcodesArray[0].Barcode, PredefinedValue("Enum.CardCodesTypes.Barcode"), False);
	
EndProcedure

// Procedure processes data of magnetic card reader transmitted from the form notification data processor.
//
&AtClient
Procedure HandleMagneticCardsReaderData(Data)
	
	ReaderData = Data;
	HandleReceivedCodeOnClient(ReaderData, PredefinedValue("Enum.CardCodesTypes.MagneticCode"), True);
	
EndProcedure

// Function checks the magnetic code against the template and returns a list of DK, magnetic code or barcode.
//
&AtServer
Function HandleReceivedCodeOnServer(Data, CardCodeType, Preprocessing, ThereAreFoundCards = False, ThereIsTemplate = False)
	
	ThereAreFoundCards = False;
	
	SetPrivilegedMode(True);
	
	CodeType = CardCodeType;
	If CodeType = Enums.CardCodesTypes.MagneticCode Then
		// When function is called, the parameter "Preprocessing" shall be set to value False in order not to use magnetic card templates.
		// Line received by lines concatenation from all magnetic tracks will be used as a card code.
		// Majority of discount cards has only one track on which only card number is recorded in the format ";CardCode?".
		If Preprocessing Then
			CurCardCode = Data[0]; // Data of 3 magnetic card tracks. At this moment it is not used. Can be used if the card is not found.
			DiscountCardsStructure = DiscountCardsServerCall.FindDiscountCardKindsByDataFromMagneticCardReader(Data, CodeType, Catalogs.DiscountCardKinds.EmptyRef());
			
			Return DiscountCardsStructure;
		Else
			If TypeOf(Data) = Type("Array") Then
				CurCardCode = Data[0];
			Else
				CurCardCode = Data;
			EndIf;
			DiscountCardsServerCall.PrepareCardCodeByDefaultSettings(CurCardCode);
			
			Return CurCardCode;
		EndIf;
	Else
		Return Data;
	EndIf;
	
EndFunction

// Function checks the magnetic code against the template and sets magnetic code or catalog item barcode.
// If there are several DK, then the user selects the appropriate code from the list.
//
&AtClient
Procedure HandleReceivedCodeOnClient(Data, ReceivedCodeType, Preprocessing)
	
	Var ThereAreFoundCards, ThereIsTemplate;
	
	Result = HandleReceivedCodeOnServer(Data, ReceivedCodeType, Preprocessing, ThereAreFoundCards, ThereIsTemplate);
	If ReceivedCodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
		If TypeOf(Result) = Type("String") Then
			FilterMagneticCode = Result;
			SmallBusinessClientServer.SetListFilterItem(List, "CardCodeMagnetic", FilterMagneticCode, ValueIsFilled(FilterMagneticCode), DataCompositionComparisonType.Contains);
		Else
			If Result.Count() = 1 Then
				FilterMagneticCode = Result.Get(0).Value;
				SmallBusinessClientServer.SetListFilterItem(List, "CardCodeMagnetic", FilterMagneticCode, ValueIsFilled(FilterMagneticCode), DataCompositionComparisonType.Contains);
			ElsIf Result.Count() = 0 Then
				SmallBusinessClient.ShowMessageAboutError(ThisObject, "Card code does not correspond to any template of magnetic cards.");
			Else
				Notification = New NotifyDescription("HandleReceivedCodeOnClientEnd", ThisForm);
				Result.ShowChooseItem(Notification, NStr("en = 'Choice of magnetic card code'"));
			EndIf;
		EndIf;
	Else
		FilterBarcode = Result;
		SmallBusinessClientServer.SetListFilterItem(List, "CardCodeBarcode", FilterBarcode, ValueIsFilled(FilterBarcode), DataCompositionComparisonType.Contains);
	EndIf;

EndProcedure

// Processor of magnetic card code choice from the list if several discount cards are found.
//
&AtClient
Procedure HandleReceivedCodeOnClientEnd(SelectItem, Parameters) Export
    If SelectItem <> Undefined Then
        FilterMagneticCode = SelectItem.Value;
		SmallBusinessClientServer.SetListFilterItem(List, "CardCodeMagnetic", FilterMagneticCode, ValueIsFilled(FilterMagneticCode), DataCompositionComparisonType.Contains);
    EndIf;
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
