
&AtClient
Var PagesStack; // History of transitions to return by clicking Back

&AtClient
Var ReaderData; // Data cache is read by a magnetic card

#Region CommonUseProceduresAndFunctions

// Function returns any attribute of discount card kind.
//
// Parameters:
//  Owner - CatalogRef.DiscountCardKinds - Kind of discount card.
//  Attribute - String - Owner attribute name.
//
&AtServerNoContext
Function GetDiscountCardKindAttribute(Owner, Attribute)

	Query = New Query;
	Query.Text = 
		"SELECT
		|	DiscountCardKinds."+Attribute+" AS Attribute
		|FROM
		|	Catalog.DiscountCardKinds AS DiscountCardKinds
		|WHERE
		|	DiscountCardKinds.Ref = &Ref";
	
	Query.SetParameter("Ref", Owner);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Attribute;
	Else
		Return Undefined;
	EndIf;
	
EndFunction // ThisIsMembershipCard(Object.DiscountCardKind)()

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	Counterparty = Parameters.Counterparty;
	
	If DefaultCodeType.IsEmpty() Then
		DefaultCodeType = DiscountCardsServer.GetDiscountCardBasicCodeType();
	EndIf;
	
	DoNotUseManualInput = Parameters.DoNotUseManualInput;
	If DoNotUseManualInput Then
		Items.GroupCardCode.Visible = False;
	EndIf;
	
	If ValueIsFilled(Parameters.CardCode) Then
		
		// On reading several cards with this code were found in
		// list form, it is required to offer cards for user to choose.
		HandleReceivedCodeOnServer(Parameters.CardCode, Parameters.CodeType, True);
		Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupChoiceDiscountCard;
		
	Else
		
		If ValueIsFilled(DefaultCodeType) Then
			CodeType = DefaultCodeType;
		Else
			CodeType = Enums.CardCodesTypes.Barcode;
		EndIf;
		
		Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupReadingDiscountCard;
		
	EndIf;
	
	Items.ButtonPagesBack.CurrentPage = Items.ButtonPagesBack.ChildItems.ButtonBackIsAbsent;
	Items.ButtonPagesNext.CurrentPage = Items.ButtonPagesNext.ChildItems.DoneButton;
	
	If Not DoNotUseManualInput Then
		If Not ValueIsFilled(DefaultCodeType) Then
			Text = NStr("en='Read the discount card with barcode"
"scanner (magnetic card reader) or enter code manually';ru='Считайте дисконтную карту при"
"помощи сканера штрихкода (считывателя магнитных карт) или введите код вручную'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
			Text = NStr("en='Read discount card with"
"magnetic card reader or enter the magnetic code manually';ru='Считайте дисконтную"
"карту при помощи считывателя магнитных карт или введите магнитный код вручную'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			Text = NStr("en='Read the discount card with"
"barcode scanner or enter barcode manually';ru='Считайте дисконтную карту"
"при помощи сканера штрихкода или введите штрихкод вручную'");
		EndIf;
	Else
		If Not ValueIsFilled(DefaultCodeType) Then
			Text = NStr("en='Read the discount card with"
"barcode scanner (magnetic card reader)';ru='Считайте дисконтную карту"
"при помощи сканера штрихкода (считывателя магнитных карт)'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
			Text = NStr("en='Read discount card with"
"magnetic cards reader';ru='Считайте дисконтную карту"
"при помощи считывателя магнитных карт'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			Text = NStr("en='Read the discount card"
"with barcode scanner';ru='Считайте дисконтную"
"карту при помощи сканера штрихкода'");
		EndIf;
	EndIf;
	LabelReadingDiscountCard = Text;

	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	// End Peripherals	
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	PagesStack = New Array;
	
	GenerateFormTitle();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,MagneticCardReader");
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

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode");
			HandleBarcodes(DiscountCardsClient.ConvertDataFromScannerIntoArray(Parameter));
		ElsIf EventName ="TracksData" Then
			CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode");
			HandleMagneticCardsReaderData(Parameter);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Procedure - event handler Clearing of item CodeType.
//
&AtClient
Procedure CodeTypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

// Procedure - event handler OnChange of item CardCode.
//
&AtClient
Procedure CardCodeOnChange(Item)
	
	If ValueIsFilled(CardCode) Then
		//AttachIdleHandler("NextWaitHandler", 0.1, True);
	EndIf;
	
EndProcedure

// Procedure - event handler Selection in values table FoundDiscountCards.
//
&AtClient
Procedure FoundDiscountCardsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	AttachIdleHandler("NextWaitHandler", 0.1, True);
	
EndProcedure

// Procedure - event handler OnChange of item DiscountCardKind.
//
&AtClient
Procedure KindDiscountCardOnChange(Item)
	
	ItemsVisibleSetupByCardKindOnServer();
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardOwner.
//
&AtClient
Procedure CardOwnerOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardCodeBarcode.
//
&AtClient
Procedure CardCodeBarcodeOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardCodeMagnetic.
//
&AtClient
Procedure CardCodeMagneticOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - command handler Back of the form.
//
&AtClient
Procedure Back(Command)
	
	If PagesStack.Count() = 0 Then
		Return;
	EndIf;
	
	Items.Pages.CurrentPage = PagesStack[PagesStack.Count()-1];
	PagesStack.Delete(PagesStack.Count()-1);
	
	If PagesStack.Count() = 0 Then
		Items.ButtonPagesBack.CurrentPage = Items.ButtonPagesBack.ChildItems.ButtonBackIsAbsent;
	EndIf;
	
	Items.ButtonPagesNext.CurrentPage = Items.ButtonPagesNext.ChildItems.DoneButton;
	
	GenerateFormTitle();
	
EndProcedure

// Procedure - command handler Next of the form.
//
&AtClient
Procedure Next(Command)
	
	DetachIdleHandler("NextWaitHandler");
	
	ClearMessages();
	
	If Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupReadingDiscountCard Then
		
		If Not ValueIsFilled(CardCode) Then
			
			If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
				MessageText = NStr("en='Barcode is not filled in.';ru='Штрихкод не заполнен.'");
			Else
				MessageText = NStr("en='Magnetic code is not filled in.';ru='Магнитный код не заполнен.'");
			EndIf;
			
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"CardCode");
			
			Return;
			
		EndIf;
		
		HandleReceivedCodeOnClient(CardCode, CodeType, False);
		
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupChoiceDiscountCard Then
		
		CurrentData = Items.FoundDiscountCards.CurrentData;
		If CurrentData <> Undefined Then
			If ValueIsFilled(CurrentData.Ref) Then
				
				ProcessDiscountCardChoice(CurrentData);
				
			Else
				
				Object.Owner = CurrentData.CardKind;
				Object.CardOwner = Counterparty;
				Object.CardCodeMagnetic = CurrentData.MagneticCode;
				Object.CardCodeBarcode = CurrentData.Barcode;
				
				ItemsVisibleSetupByCardKindOnServer();
				Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
				
				GoToPage(Items.Pages.ChildItems.GroupDiscountCardCreate);	
				
			EndIf;
		EndIf;
		
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupDiscountCardCreate Then
		
		If WriteDiscountCard() Then
		
			CloseParameters = New Structure("DiscountCard, DiscountCardRead", Object.Ref, False);
			Close(CloseParameters);
				
		EndIf;
		
	EndIf;
	
EndProcedure

// Function records current object and returns True if it is successfully recorded
//
&AtServer
Function WriteDiscountCard()

	If CheckFilling() Then
		Try
			Write();
			Return True;
		Except
			Message = New UserMessage;
			Message.Text = ErrorDescription();
			Message.SetData();
			Message.Message();
			Return False;
		EndTry;			
	Else
		Return False;
	EndIf;

EndFunction

// Procedure generates a form title depending on the current page and selected row in values table of
// found discount cards or discount cards kinds
//
&AtClient
Procedure GenerateFormTitle()
	
	If Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupReadingDiscountCard Then
		ThisForm.AutoTitle = False;
		ThisForm.Title = "Read discount card";
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupChoiceDiscountCard Then
		ThisForm.AutoTitle = False;
		CurrentData = Items.FoundDiscountCards.CurrentData;
		If CurrentData <> Undefined Then
			If ValueIsFilled(CurrentData.Ref) Then
				ThisForm.Title = "Selection of discount card";
			Else
				ThisForm.Title = "Select a new discount card kind";
			EndIf;
		Else
			If FoundDiscountCards.Count() > 0 Then
				If ValueIsFilled(FoundDiscountCards[0].Ref) Then
					ThisForm.Title = "Selection of discount card";
				Else
					ThisForm.Title = "Select a new discount card kind";
				EndIf;
			Else
				ThisForm.Title = "Select a discount card \ new discount card kind";
			EndIf;
		EndIf;			
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupDiscountCardCreate Then
	    ThisForm.AutoTitle = True;
		ThisForm.Title = "";
	EndIf;
	
EndProcedure

// Procedure - command handler CopyBCInMC of the form.
//
&AtClient
Procedure CopyBCInMC(Command)
	
	Object.CardCodeMagnetic = Object.CardCodeBarcode;
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - command handler CopyMCInBC of the form.
//
&AtClient
Procedure CopyMCInBC(Command)
	
	Object.CardCodeBarcode = Object.CardCodeMagnetic;
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

&AtClient
Procedure Attachable_ExecuteOverriddenCommand(Command)
	
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure configures reference format and form filters.
//
&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FoundDiscountCards.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("FoundDiscountCards.Ref");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("FoundDiscountCards.AutomaticRegistrationOnFirstReading");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("BackColor", New Color());
	Item.Appearance.SetParameterValue("TextColor", WebColors.MediumGray);

EndProcedure

#Region BarcodesAndShopEquipment

// Procedure processes barcode data transmitted from form notifications data processor.
//
&AtClient
Procedure HandleBarcodes(BarcodesData)
	
	If Items.Pages.CurrentPage <> Items.Pages.ChildItems.GroupReadingDiscountCard Then
		Return;
	EndIf;
	
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
	
	If Items.Pages.CurrentPage <> Items.Pages.ChildItems.GroupReadingDiscountCard Then
		Return;
	EndIf;
	
	ReaderData = Data;
	AttachIdleHandler("HandleReceivedCodeOnClientInWaitProcessor", 0.1, True);
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure GoToPage(Page)
	
	PagesStack.Add(Items.Pages.CurrentPage);
	Items.Pages.CurrentPage = Page;
	Items.ButtonPagesBack.CurrentPage = Items.ButtonPagesBack.ChildItems.ButtonBack;
	
	If Page = Items.Pages.ChildItems.GroupChoiceDiscountCard Then
		If CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
			Text = NStr("en='Several discount cards with magnetic code ""%1"" are detected."
"Select suitable card.';ru='Обнаружено несколько дисконтных карт с магнитным кодом ""%1""."
"Выберите подходящую карту.'");
		Else
			Text = NStr("en='Several discount cards with barcode ""%1"" are detected."
"Select suitable card.';ru='Обнаружено несколько дисконтных карт со штрихкодом ""%1""."
"Выберите подходящую карту.'");
		EndIf;
		LabelChoiceDiscountCard = StringFunctionsClientServer.PlaceParametersIntoString(Text, CardCode);
	EndIf;
	
	GenerateFormTitle();
	
EndProcedure

// Function checks the magnetic code against the template and returns a list of DK, magnetic code or barcode.
//
&AtServer
Function HandleReceivedCodeOnServer(Data, CardCodeType, Preprocessing, ThereAreFoundCards = False)
	
	ThereAreFoundCards = False;
	
	SetPrivilegedMode(True);
	
	FoundDiscountCards.Clear();
	
	CodeType = CardCodeType;
	If CodeType = Enums.CardCodesTypes.MagneticCode Then
		// When function is called, the parameter "Preprocessing" shall be set to value False in order not to use magnetic card templates.
		// Line received by lines concatenation from all magnetic tracks will be used as a card code.
		// Majority of discount cards has only one track on which only card number is recorded in the format ";CardCode?".
		If Preprocessing Then
			CardCode = Data[0]; // Data of 3 magnetic card tracks. At this moment it is not used. Can be used if the card is not found.
			                         // When a card does not correspond to any template, the warning will appear but the button "Ready" in the form will not be pressed.
			DiscountCards = DiscountCardsServerCall.FindDiscountCardsByDataFromMagneticCardReader(Data, CodeType);
		Else
			If TypeOf(Data) = Type("Array") Then
				CardCode = Data[0];
			Else
				CardCode = Data;
			EndIf;
			DiscountCardsServerCall.PrepareCardCodeByDefaultSettings(CardCode);
			DiscountCards = DiscountCardsServer.FindDiscountCardsByMagneticCode(CardCode);
		EndIf;
		
		Items.FoundDiscountCardsMagneticCode.Visible = True;
	Else
		CardCode = Data;
		DiscountCards = DiscountCardsServerCall.FindDiscountCardsByBarcode(CardCode);
		
		Items.FoundDiscountCardsMagneticCode.Visible = False;
	EndIf;
	
	For Each TSRow IN DiscountCards.RegisteredDiscountCards Do
		
		ThereAreFoundCards = True;
		
		NewRow = FoundDiscountCards.Add();
		FillPropertyValues(NewRow, TSRow);
		
		NewRow.Description = String(TSRow.Ref) + ?(ValueIsFilled(TSRow.Counterparty) AND ValueIsFilled(TSRow.Ref), StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=' Client: %1';ru=' Клиент: %1'"), String(TSRow.Counterparty)), "");
		
	EndDo;
	
	If DiscountCards.RegisteredDiscountCards.Count() = 0 Then
		For Each TSRow IN DiscountCards.NotRegisteredDiscountCards Do
			
			NewRow = FoundDiscountCards.Add();
			FillPropertyValues(NewRow, TSRow);
			
			NewRow.Description = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Register a new card: %1';ru='Зарегистрировать новую карту: %1'"), String(TSRow.CardKind))+?(TSRow.ThisIsMembershipCard, " (Named, ", " (")+TSRow.CardType+")";
			
		EndDo;
	EndIf;
	
	Return FoundDiscountCards.Count() > 0;
	
EndFunction

// Function checks the magnetic code against the template and sets magnetic code or catalog item barcode.
//
&AtClient
Procedure HandleReceivedCodeOnClient(Data, ReceivedCodeType, Preprocessing)
	
	Var ThereAreFoundCards;
	
	Result = HandleReceivedCodeOnServer(Data, ReceivedCodeType, Preprocessing, ThereAreFoundCards);
	If Not Result Then
		
		If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			MessageText = NStr("en='Card with barcode ""%1"" is not registered and there is no suitable kind of discount card.';ru='Карта со штрихкодом ""%1"" не зарегистрирована и нет ни одного подходящего вида дисконтных карт.'");
		Else
			MessageText = NStr("en='Card with magnetic code ""%1"" is not registered and there is no suitable kind of discount card.';ru='Карта с магнитным кодом ""%1"" не зарегистрирована и нет ни одного подходящего вида дисконтных карт.'");
		EndIf;
		
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.PlaceParametersIntoString(MessageText, CardCode),
			,
			"CardCode");
		
		Return;
		
	EndIf;
	
	If FoundDiscountCards.Count() > 1 OR Not ThereAreFoundCards Then
		GoToPage(Items.Pages.ChildItems.GroupChoiceDiscountCard);
		If ThereAreFoundCards Then		
			Text = NStr("en='Several discount cards with code ""%1"" are detected."
"Select suitable card.';ru='Обнаружено несколько дисконтных карт с кодом ""%1""."
"Выберите подходящую карту.'");
			LabelChoiceDiscountCard = StringFunctionsClientServer.PlaceParametersIntoString(Text, CardCode);
		Else // Only the kinds of cards for new card registration.
			If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
				Text = NStr("en='Card with barcode ""% 1"" is not registered."
"Select a suitable kind of card for registration of new discount card.';ru='Карта со штрихкодом ""%1"" не зарегистрирована."
"Выберите подходящий вид карты для регистрации новой дисконтной карты.'");
			Else
				Text = NStr("en='Card with magnetic code ""%1"" is not registered."
"Select a suitable kind of card for registration of new discount card.';ru='Карта с магнитным кодом ""%1"" не зарегистрирована."
"Выберите подходящий вид карты для регистрации новой дисконтной карты.'");			   
			EndIf;				   
			LabelChoiceDiscountCard = StringFunctionsClientServer.PlaceParametersIntoString(Text, CardCode);
		EndIf;
	ElsIf FoundDiscountCards.Count() = 1 AND ThereAreFoundCards Then
		ProcessDiscountCardChoice(FoundDiscountCards[0]);
	EndIf;
	
EndProcedure

// Procedure gets called when the user selects a particular discount card.
//
&AtClient
Procedure ProcessDiscountCardChoice(CurrentData)
	
	CloseParameters = New Structure("DiscountCard, DiscountCardRead", CurrentData.Ref, True);
	Close(CloseParameters);
	
EndProcedure

// Function checks magnetic code against template and sets magnetic code of catalog item or displays list of DK or DK kinds.
//
&AtClient
Procedure HandleReceivedCodeOnClientInWaitProcessor()
	
	HandleReceivedCodeOnClient(ReaderData, PredefinedValue("Enum.CardCodesTypes.MagneticCode"), True);
	
EndProcedure

// Procedure clicks Next in wait handler after changing card code or choice of discount card (discount card kind).
//
&AtClient
Procedure NextWaitHandler()
	
	Next(Commands["Next"]);
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure configures items visible depending on attributes of discount card kind.
//
&AtServer
Procedure ItemsVisibleSetupByCardKindOnServer()
	
	If Not Object.Owner.IsEmpty() Then
		Membership = GetDiscountCardKindAttribute(Object.Owner, "ThisIsMembershipCard");
		CardType = GetDiscountCardKindAttribute(Object.Owner, "CardType");
	Else
		Membership = False;
		CardType = PredefinedValue("Enum.CardsTypes.EmptyRef");		
	EndIf;
	
	Items.CardOwner.AutoMarkIncomplete = Membership;
	
	Items.CardOwner.Visible = Membership;
	Items.ThisIsMembershipCard.Visible = Membership;
	
	Items.CardCodeMagnetic.Visible = (CardType = PredefinedValue("Enum.CardsTypes.Magnetic")
	                                        Or CardType = PredefinedValue("Enum.CardsTypes.Mixed"));
	Items.CardCodeBarcode.Visible = (CardType = PredefinedValue("Enum.CardsTypes.Barcode")
	                                        Or CardType = PredefinedValue("Enum.CardsTypes.Mixed"));
											
	If CardType = PredefinedValue("Enum.CardsTypes.Mixed") Then
		If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			Items.CopyMCInBC.Visible = False;
			Items.CopyBCInMC.Visible = True;
		Else
			Items.CopyMCInBC.Visible = True;
			Items.CopyBCInMC.Visible = False;
		EndIf;
	Else
		Items.CopyMCInBC.Visible = False;
		Items.CopyBCInMC.Visible = False;
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
