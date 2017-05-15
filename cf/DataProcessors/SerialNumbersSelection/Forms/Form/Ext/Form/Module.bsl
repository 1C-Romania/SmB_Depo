
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ThisIsReciept") Then
		ThisIsReciept = Parameters.ThisIsReciept;
	Else
		ThisIsReciept = False;
	EndIf;
	
	MessageText = "";
	If NOT Parameters.Property("Inventory") OR NOT ValueIsFilled(Parameters.Inventory.ProductsAndServices) Then
		MessageText = NStr("ru = 'Не заполнена номенклатура!'; en = 'Products and services are not filled!'");
	ElsIf NOT Parameters.Inventory.ProductsAndServices.UseSerialNumbers Then
		MessageText = NStr("ru = 'Для номенклатуры не ведется учет по серийным номерам!'; en = 'No account by serial numbers for this products!'");
	EndIf;
	
	If NOT IsBlankString(MessageText) Then
		CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
		Return;
	EndIf;
	OwnerFormUUID = Parameters.OwnerFormUUID;
	
	If Parameters.Property("PickMode") Then
		PickMode = Parameters.PickMode;
	Else
		Cancel = True;
	EndIf;
	
	If ValueIsFilled(Parameters.AddressInTemporaryStorage) Then
		SavedSerialNumbersValue = GetFromTempStorage(Parameters.AddressInTemporaryStorage);
		If TypeOf(SavedSerialNumbersValue) = Type("CatalogRef.SerialNumbers") Then
			If ValueIsFilled(SavedSerialNumbersValue) Then
				NewRow = Object.SerialNumbers.Add();
				NewRow.SerialNumber = SavedSerialNumbersValue;
				NewRow.NewNumber = String(SavedSerialNumbersValue);
			EndIf; 
		Else
			
			// If the document is used Marking GoodsГИСМ, then it has a special order of loading the series
			LoadSeriesSeparately = (SavedSerialNumbersValue.Columns.Find("Series")<>Undefined);
			
			For Each LoadingString In SavedSerialNumbersValue Do
				SerialNumbersString = Object.SerialNumbers.Add();
				FillPropertyValues(SerialNumbersString, LoadingString);
				
				If LoadSeriesSeparately Then
					SerialNumbersString.SerialNumber = LoadingString.Series;
				EndIf;
				
			EndDo;
			
			For Each Str In Object.SerialNumbers Do
				
				SerialNumberData = CommonUse.ObjectAttributesValues(Str.SerialNumber, "Description" );
				FillPropertyValues(Str, SerialNumberData);
				Str.NewNumber = SerialNumberData.Description;
				
			EndDo;
		EndIf; 
	EndIf;
	
	FillInventory(Parameters.Inventory);
	ListOfSelected.LoadValues(Object.SerialNumbers.Unload().UnloadColumn("SerialNumber"));
	
	If GetFunctionalOption("SerialNumbersBalanceControl") Then
		
		SerialNumbersBalance.QueryText = QueryTextSeriesBalances();
		
		SerialNumbersBalance.Parameters.SetParameterValue("ProductsAndServices", ProductsAndServices);
		SerialNumbersBalance.Parameters.SetParameterValue("Company", Parameters.Company);
		SerialNumbersBalance.Parameters.SetParameterValue("Characteristic", Parameters.Inventory.Characteristic);
		SerialNumbersBalance.Parameters.SetParameterValue("Batch", Parameters.Inventory.Batch);
		If Parameters.Property("StructuralUnit") Then
			SerialNumbersBalance.Parameters.SetParameterValue("StructuralUnit",Parameters.StructuralUnit);
			SerialNumbersBalance.Parameters.SetParameterValue("AllWarehouses", False);
			
			If ValueIsFilled(Parameters.StructuralUnit) Then
				Items.SeriesBalancesSerie.Title = NStr("ru = 'В наличии на '; en = 'Available in '") + Parameters.StructuralUnit;
			EndIf;
		Else
			SerialNumbersBalance.Parameters.SetParameterValue("StructuralUnit", Undefined);
			SerialNumbersBalance.Parameters.SetParameterValue("AllWarehouses", True);
		EndIf;
		If Parameters.Property("Cell") Then
			SerialNumbersBalance.Parameters.SetParameterValue("Cell",Parameters.Cell);
			SerialNumbersBalance.Parameters.SetParameterValue("AllCells", False);
			
			If ValueIsFilled(Parameters.Cell) Then
				Items.SeriesBalancesSerie.Title = Items.SeriesBalancesSerie.Title + ", " + Parameters.Cell;
			EndIf;
		Else
			SerialNumbersBalance.Parameters.SetParameterValue("Cell", Undefined);
			SerialNumbersBalance.Parameters.SetParameterValue("AllCells", True);
		EndIf;
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected", ListOfSelected.UnloadValues());
		SerialNumbersBalance.Parameters.SetParameterValue("ThisDocument", Parameters.DocRef);
		
		Items.ShowSold.Visible = False;
		Items.SeriesBalancesSold.Visible = ShowSold;
		
	Else // Without balance
		
		SerialNumbersBalance.QueryText = QueryTextSerialNumbers();
		SerialNumbersBalance.Parameters.SetParameterValue("ProductsAndServices",ProductsAndServices);
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
		SerialNumbersBalance.Parameters.SetParameterValue("ShowSold", ShowSold);
		SerialNumbersBalance.Parameters.SetParameterValue("ThisDocument", Parameters.DocRef);
		
	EndIf;
	
	//SN template
	RestoreSettings();
	
	Items.GroupFill.Visible = False;
	If NOT ValueIsFilled(Characteristic) Then
		Items.Characteristic.Visible = False;
	EndIf;
	If NOT ValueIsFilled(Batch) Then
		Items.Batch.Visible = False;
	EndIf;
	
	If PickMode Then
		Items.Pages.CurrentPage = Items.BalancesChoice;
	Else
		Items.Pages.CurrentPage = Items.AddingNew;
	EndIf;
	
	SetConditionalAppearance();
	
	Items.SerialNumbersUpdatePeriodAction.ChoiceList.Add("Generate numbers in order");
	Items.SerialNumbersUpdatePeriodAction.ChoiceList.Add("Fill with numbers frome the range");
	
EndProcedure

&AtServer
Function QueryTextSeriesBalances()
	
	RequestText = "SELECT DISTINCT
	|	NestedSelect.SerialNumber
	|FROM
	|	(SELECT
	|		SerialNumbersBalance.SerialNumber AS SerialNumber
	|	FROM
	|		AccumulationRegister.SerialNumbers.Balance(
	|				,
	|				Company = &Company
	|					AND ProductsAndServices = &ProductsAndServices
	|					AND Characteristic = &Characteristic
	|					AND Batch = &Batch
	|					AND (&AllWareHouses
	|						OR &StructuralUnit = &StructuralUnit)
	|					AND (&AllCells
	|						OR Cell = &Cell)
	|					AND NOT SerialNumber IN (&ListOfSelected)) AS SerialNumbersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SerialNumbers.SerialNumber
	|	FROM
	|		AccumulationRegister.SerialNumbers AS SerialNumbers
	|	WHERE
	|		SerialNumbers.Recorder = &ThisDocument
	|		AND NOT SerialNumbers.SerialNumber IN (&ListOfSelected)
	|		AND SerialNumbers.SerialNumber.Owner = &ProductsAndServices) AS NestedSelect";
	
	Return RequestText;
	
EndFunction

&AtServer
Function QueryTextSerialNumbers()
	
	RequestText = "SELECT DISTINCT
	|	NestedQuery.SerialNumber,
	|	NestedQuery.Sold
	|FROM
	|	(SELECT
	|		CatalogSerialNumbers.Ref AS SerialNumber,
	|		CatalogSerialNumbers.Sold AS Sold
	|	FROM
	|		Catalog.SerialNumbers AS CatalogSerialNumbers
	|	WHERE
	|		CatalogSerialNumbers.Owner = &ProductsAndServices
	|		AND NOT CatalogSerialNumbers.Ref IN (&ListOfSelected)
	|		AND CASE
	|			WHEN &ShowSold
	|				THEN TRUE
	|			ELSE NOT CatalogSerialNumbers.Sold
	|		END
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SerialNumbers.SerialNumber,
	|		SerialNumbers.SerialNumber.Sold
	|	FROM
	|		AccumulationRegister.SerialNumbers AS SerialNumbers
	|	WHERE
	|		SerialNumbers.Recorder = &ThisDocument
	|		AND NOT SerialNumbers.SerialNumber IN (&ListOfSelected)
	|		AND SerialNumbers.SerialNumber.Owner = &ProductsAndServices) AS NestedQuery";
	
	Return RequestText;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SeriesSerie.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.SerialNumbers.SerialNumber");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Новый'; en = 'New'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SeriesSerie.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.SerialNumbers.SerialNumber");
	FilterElement.ComparisonType = DataCompositionComparisonType.Filled;
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Зарегистрированный'; en = 'Registered'"));

EndProcedure

&AtServer
Function SaveSerialNumbersInput()
	
	VTSerialNumbers = Object.SerialNumbers.Unload();
	Object.SerialNumbers.Load(VTSerialNumbers);
	
	For Each TableStr In Object.SerialNumbers Do
		
		If Not ValueIsFilled(TableStr.SerialNumber) Then
			
			CatalogObject                = Catalogs.SerialNumbers.CreateItem();
			CatalogObject.Owner		= ProductsAndServices;
			CatalogObject.Description	= TableStr.NewNumber;
			
			FillPropertyValues(CatalogObject, TableStr);
			
			Try
				CatalogObject.Write();	
			Except
				Message(ErrorDescription());
				Return False;
			EndTry;
			
			TableStr.SerialNumber = CatalogObject.Ref;
		EndIf;
		
	EndDo;
	
	AddressInTemporaryStorage = PutToTempStorage(Object.SerialNumbers.Unload());
	Modified = False;
	
	Return True;

EndFunction

&AtServer
Procedure FillInventory(Inventory)
	
	ProductsAndServices = Inventory.ProductsAndServices;
	Characteristic = Inventory.Characteristic;
	If Inventory.Property("Batch") Then
		Batch = Inventory.Batch;
	EndIf;
	If Inventory.Property("MeasurementUnit") Then
		MeasurementUnit = Inventory.MeasurementUnit;
		CountInADocument = Inventory.Quantity * Inventory.Ratio;
	Else
		CountInADocument = Inventory.Quantity;
	EndIf;
	
	If Inventory.Property("ConnectionKey") Then
		ConnectionKey = Inventory.ConnectionKey;
	EndIf;
	
EndProcedure

&AtClient
Procedure Complete(Command)
	
	SavedSuccess = SaveSerialNumbersInput();
	If SavedSuccess Then
	
		ReturnStructure = New Structure("RowKey, AddressInTemporaryStorage, ThisIsReciept", ConnectionKey, AddressInTemporaryStorage, ThisIsReciept);
		Notify("SerialNumbersSelection", ReturnStructure, 
			?(OwnerFormUUID = New UUID("00000000-0000-0000-0000-000000000000"), Undefined, OwnerFormUUID)
			);
		Close();
	
	EndIf; 
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If NOT PickMode 
		Then
		SaveSettings();
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	SettingsString = "TemplateSerialNumber";
	SystemSettingsStorage.Save(ThisForm.FormName, ThisForm.FormName+"_TemplateSerialNumber", ThisForm.TemplateSerialNumber);
	
EndProcedure

&AtServer
Procedure RestoreSettings()
	
	SettingsString = "TemplateSerialNumber";
	ThisForm.TemplateSerialNumber = SystemSettingsStorage.Load(ThisForm.FormName, ThisForm.FormName+"_TemplateSerialNumber", ThisForm.TemplateSerialNumber);
	
	Items.SeriesNumber.Mask = WorkWithSerialNumbersClientServer.StringOfMaskByTemplate(TemplateSerialNumber);
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtServer
Function EvaluateMaximumNumberAndCount()
	
	MaximumNumberFromCatalog = Catalogs.SerialNumbers.CalculateMaximumSerialNumber(ProductsAndServices, TemplateSerialNumber);
	MaximumNumberInADocument = 0;
	For Each Str In Object.SerialNumbers Do
		
		If NOT ValueIsFilled(Str.SerialNumber) AND Str.SerialNumberNumeric=0 AND ValueIsFilled(Str.NewNumber) Then
			TemplateSerialNumberAsString = ?(ValueIsFilled(TemplateSerialNumber),TemplateSerialNumber,"########");
			
			Str.SerialNumberNumeric = Catalogs.SerialNumbers.SerialNumberNumericByTemplate(Str.NewNumber, TemplateSerialNumberAsString);
		
		EndIf;
		
		MaximumNumberInADocument = Max(MaximumNumberInADocument, Str.SerialNumberNumeric);
	EndDo;
	
	Number = Max(MaximumNumberInADocument,MaximumNumberFromCatalog);
	
	Return Number;
	
EndFunction

&AtServer
Procedure GenerateSerialNumbersServer(CountGenerate, InitialNumber = Undefined)
	
	If InitialNumber = Undefined Then
		NextNumberByOrder = EvaluateMaximumNumberAndCount()+1;
	Else
		NextNumberByOrder = InitialNumber;
	EndIf;
	
	For nString=1 To CountGenerate Do
	   	NewNumberStructure = AddSerialNumberByTemplate(NextNumberByOrder);
		
		CurrentRow = Object.SerialNumbers.Add();
		CurrentRow.NewNumber = NewNumberStructure.NewNumber;
		CurrentRow.SerialNumberNumeric = NewNumberStructure.NewNumberNumeric;
		
		NextNumberByOrder = NextNumberByOrder+1;
	EndDo;
		
EndProcedure

&AtServer
Function AddSerialNumberServer()

	NextNumberByOrder = EvaluateMaximumNumberAndCount()+1;
	Return AddSerialNumberByTemplate(NextNumberByOrder);
	
EndFunction

&AtServer
Function AddSerialNumberByTemplate(CurrentMaximumNumber)
		
	NumberNumeric = CurrentMaximumNumber;
	
	If ValueIsFilled(TemplateSerialNumber) Then
		//Length of the digital part of the number - no more than 13 symbols
		DigitInTemplate = StrOccurrenceCount(TemplateSerialNumber, WorkWithSerialNumbersClientServer.CharNumber());
		CountOfCharactersSN = Max(DigitInTemplate, StrLen(NumberNumeric));
		NumberWithZeros = Format(NumberNumeric, "ND="+DigitInTemplate+"; NLZ=; NG=");
		
		NewNumberByTemplate = "";
		CharacterNumberSN = 1;
		//Filling the template
		For n=1 To StrLen(TemplateSerialNumber) Do
			Symb = Mid(TemplateSerialNumber,n,1);
			If Symb=WorkWithSerialNumbersClientServer.CharNumber() Then
				NewNumberByTemplate = NewNumberByTemplate+Mid(NumberWithZeros,CharacterNumberSN,1);
				CharacterNumberSN = CharacterNumberSN+1;
			Else
				NewNumberByTemplate = NewNumberByTemplate+Symb;
			EndIf;
		EndDo;
		NewNumber = NewNumberByTemplate;
	Else
		NewNumber = Format(NumberNumeric, "ND=8; NLZ=; NG=");
	EndIf;
	
	Return New Structure("NewNumber, NewNumberNumeric", NewNumber, NumberNumeric);
	
EndFunction

&AtClient
Procedure AddSerialNumber(Command)
	
	NewNumberStructure = AddSerialNumberServer();
	
	Items.SerialNumbersNew.AddRow();
	CurrentData = Items.SerialNumbersNew.CurrentData;
	CurrentData.NewNumber = NewNumberStructure.NewNumber;
	CurrentData.SerialNumberNumeric = NewNumberStructure.NewNumberNumeric;
	
	Items.SerialNumbersNew.EndEditRow(False);	
	
EndProcedure

&AtServer
Procedure FindRegistredSeries()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	SerialNumbers.NewNumber AS NewNumber,
	|	CASE
	|		WHEN SerialNumbers.SerialNumber = """"
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NumberNotSpecified,
	|	SerialNumbers.LineNumber AS LineNumber
	|INTO NewSerialNumbers
	|FROM
	|	&SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbers.Ref AS SerialNumber,
	|	NewSerialNumbers.LineNumber,
	|	SerialNumbers.Description AS NewNumber
	|FROM
	|	NewSerialNumbers AS NewSerialNumbers
	|		LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON NewSerialNumbers.NewNumber = SerialNumbers.Description
	|WHERE
	|	SerialNumbers.Owner = &ProductsAndServices";
	
	Query.SetParameter("ProductsAndServices", ProductsAndServices);
	Query.SetParameter("SerialNumbers",Object.SerialNumbers.Unload());

	Selection = Query.Execute().Select();
			
	While Selection.Next() Do
		Object.SerialNumbers[Selection.LineNumber-1].SerialNumber = Selection.SerialNumber;
	EndDo;
	
EndProcedure	

&AtClient
Procedure SeriesNumberOnChange(Item)
	
	CurRow = Object.SerialNumbers.FindByID(Items.SerialNumbersNew.CurrentRow);
	If CurRow<>Undefined Then
		CurRow.SerialNumber = Undefined;
	EndIf;
	FindRegistredSeries();
	
EndProcedure

&AtClient
Procedure SeriesNumberStartChoice(Item, ChoiceData, StandardProcessing)
	
	ChooseSerieNotification = New NotifyDescription("ChooseSerieCompletion", ThisObject);
	
	FilterStructure = New Structure("Filter", New Structure("Owner", ThisObject.ProductsAndServices));
	If ValueIsFilled(Items.SerialNumbersNew.CurrentData.SerialNumber) Then
		FilterStructure.Insert("CurrentRow", Items.SerialNumbersNew.CurrentData.SerialNumber);
	EndIf;
	OpenForm("Catalog.SerialNumbers.ChoiceForm", FilterStructure, ThisObject,,,,ChooseSerieNotification);
	
EndProcedure

&AtClient
Procedure ChooseSerieCompletion(ClosingResult, ExtendedParameters) Export
	
	If ClosingResult<>Undefined Then
		CurRow = Object.SerialNumbers.FindByID(Items.SerialNumbersNew.CurrentRow);
		CurRow.NewNumber	= String(ClosingResult);
		CurRow.SerialNumber = ClosingResult;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseNumber(Command)
	
	If Items.SeriesBalances.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ChosenSerialNumber = Items.SeriesBalances.CurrentData.SerialNumber;
	AddChosenSerialNumber(ChosenSerialNumber);
	
EndProcedure

&AtClient
Procedure AddChosenSerialNumber(SerialNumber)
	
	Items.ChosenSerialNumbers.AddRow();
	
	Items.ChosenSerialNumbers.CurrentData.SerialNumber = SerialNumber;
	Items.ChosenSerialNumbers.CurrentData.NewNumber = String(SerialNumber);
	Items.ChosenSerialNumbers.EndEditRow(False);
	
	ListOfSelected.Add(SerialNumber);
	
	SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
	
EndProcedure

&AtClient
Procedure RemoveNumber(Command)

	If Items.ChosenSerialNumbers.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ChosenSerialNumber = Items.ChosenSerialNumbers.CurrentData.SerialNumber;
	RemoveChosenSerialNumber(ChosenSerialNumber);
	
EndProcedure

&AtClient
Procedure RemoveChosenSerialNumber(SerialNumber)

	Object.SerialNumbers.Delete(Items.ChosenSerialNumbers.CurrentData.LineNumber - 1);
	
	FoundElement = ListOfSelected.FindByValue(SerialNumber);
	If FoundElement<>Undefined Then
		ListOfSelected.Delete(FoundElement);
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
	EndIf;
	
	If Items.SeriesBalances.CurrentRow = Undefined Then
		Items.SeriesBalances.CurrentRow = 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure TemplateSerialNumberOnChange(Item)
	
	Items.SeriesNumber.Mask = WorkWithSerialNumbersClientServer.StringOfMaskByTemplate(TemplateSerialNumber);

EndProcedure

&AtClient
Procedure SeriesBalancesChoice(Item, RowSelected, Field, StandardProcessing)
	
	ChooseNumber(Undefined);
	
EndProcedure

&AtClient
Procedure ChosenSeriesChoice(Item, RowSelected, Field, StandardProcessing)
	
	RemoveNumber(Undefined);
	
EndProcedure

&AtClient
Procedure SoldOnChange(Item)
	
	Items.SeriesBalancesSold.Visible = ShowSold;
	SerialNumbersBalance.Parameters.SetParameterValue("ShowSold", ShowSold);
	
EndProcedure

&AtClient
Procedure ChosenSeriesNewNumberOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.SerialNumbers.ObjectForm", New Structure("Key",Items.ChosenSerialNumbers.CurrentData.SerialNumber));
	
EndProcedure

&AtClient
Procedure OpenSerialNumber(Command)
	
	If Items.ChosenSerialNumbers.CurrentData <> Undefined Then
	
		OpenForm("Catalog.SerialNumbers.ObjectForm", New Structure("Key",Items.ChosenSerialNumbers.CurrentData.SerialNumber));
	
	EndIf; 
	
EndProcedure

&AtServer
Procedure AddExecuteAtServer()

	If SerialNumbersUpdatePeriodAction = Items.SerialNumbersUpdatePeriodAction.ChoiceList[0].Value Then
		
		GenerateSerialNumbersServer(SerialNumbersRowsApdateCount);
		
	ElsIf SerialNumbersUpdatePeriodAction = Items.SerialNumbersUpdatePeriodAction.ChoiceList[1].Value Then
		Items.SerialNumbersRowsChangeFrom.Visible = True;
		
		For n=SerialNumbersRowsChangeFrom To SerialNumbersRowsChangeUntil Do
		   	NewNumberStructure = AddSerialNumberByTemplate(n);
			
			CurrentRow = Object.SerialNumbers.Add();
			CurrentRow.NewNumber = NewNumberStructure.NewNumber;
			CurrentRow.SerialNumberNumeric = NewNumberStructure.NewNumberNumeric;
			
		EndDo;
		FindRegistredSeries();
	EndIf;
	
	VTSerialNumbers = Object.SerialNumbers.Unload();
	VTSerialNumbers.GroupBy("SerialNumber, NewNumber");
	Object.SerialNumbers.Load(VTSerialNumbers);
	
EndProcedure

&AtClient
Procedure AddExecute(Command)
	
	AddExecuteAtServer();

EndProcedure

&AtClient
Procedure AddCancel(Command)
	
	Items.GroupFill.Visible = False;
	
EndProcedure

&AtClient
Procedure FillClick(Command)
	
	Items.GroupFill.Visible = NOT Items.GroupFill.Visible;
	SerialNumbersUpdatePeriodAction = Items.SerialNumbersUpdatePeriodAction.ChoiceList[0].Value;
	SerialNumbersRowsApdateCount = Max(CountInADocument - Object.SerialNumbers.Count(), 1);
	
EndProcedure

&AtClient
Procedure SerialNumbersRawsUpdateActionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Items.SerialNumbersUpdatePeriodAction.ChoiceList[0].Value Then
		Items.SerialNumbersRowsApdateCount.Visible = True;
		Items.SerialNumbersRowsChangeFrom.Visible = False;
		Items.SerialNumbersRowsChangeUntil.Visible = False;
		SerialNumbersRowsApdateCount = Max(CountInADocument - Object.SerialNumbers.Count(), 1);
		
	ElsIf ValueSelected = Items.SerialNumbersUpdatePeriodAction.ChoiceList[1].Value Then
		Items.SerialNumbersRowsApdateCount.Visible = False;
		Items.SerialNumbersRowsChangeFrom.Visible = True;
		Items.SerialNumbersRowsChangeUntil.Visible = True;
		
		CurrentMaximumNumber = EvaluateMaximumNumberAndCount();
		SerialNumbersRowsChangeFrom = CurrentMaximumNumber + 1;
		SerialNumbersRowsChangeUntil = CurrentMaximumNumber + 1 + CountInADocument - Object.SerialNumbers.Count();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SeriesNumberOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.SerialNumbers.ObjectForm", New Structure("Key",Items.SerialNumbersNew.CurrentData.SerialNumber));
	
EndProcedure

&AtClient
Procedure ChosenSeriesBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ChosenSeriesDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	SerialNumbersArray = DragParameters.Value;
	For Each Str In SerialNumbersArray Do
		RowData = Items.SeriesBalances.RowData(Str);
		If RowData<>Undefined Then
			AddChosenSerialNumber(RowData.SerialNumber);
		EndIf;
	EndDo;

EndProcedure

&AtClient
Procedure ChosenSerialNumbersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	ChosenSerialNumber = Items.ChosenSerialNumbers.CurrentData.SerialNumber;
	RemoveChosenSerialNumber(ChosenSerialNumber);
	
EndProcedure

&AtClient
Procedure FillByAvailability(Command)
	
	LeftToChoose = CountInADocument - Object.SerialNumbers.Count();
	If LeftToChoose>0 Then
		FillSerialNumbersByAvailability(LeftToChoose);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSerialNumbersByAvailability(AddCount)

	Query = New Query;
	Query.Text = SerialNumbersBalance.QueryText;
	Query.Text = StrReplace(Query.Text, "SELECT ", "SELECT TOP "+AddCount+" ");
	For Each param In SerialNumbersBalance.Parameters.Items Do
		Query.SetParameter(String(param.Parameter), param.Value);
	EndDo;
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		NewRow = Object.SerialNumbers.Add();
		NewRow.SerialNumber = Selection.SerialNumber;
		NewRow.NewNumber = String(Selection.SerialNumber);
		
		ListOfSelected.Add(Selection.SerialNumber);
	EndDo;
	
	SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
	
EndProcedure	

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.BalancesChoice Then
		ListOfSelected.Clear();
		For Each ChNumber In Object.SerialNumbers Do
			If ValueIsFilled(ChNumber.SerialNumber) Then
				ListOfSelected.Add(ChNumber.SerialNumber);	
			EndIf;
		EndDo;
		
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
	EndIf;
	
EndProcedure

&AtClient
Procedure Pickup(Command)
	
	Notification = New NotifyDescription("RecievedSerialNumbersPickup", ThisObject);
	StructureFilter = New Structure("Multiselect", True);
	StructureFilter.Insert("Filter", New Structure("Owner, DeletionMark", ProductsAndServices, False));
	
	ListFormSN = OpenForm("Catalog.SerialNumbers.Form.ChoiceForm", StructureFilter, ThisObject,,,,Notification);
	
EndProcedure

&AtClient
Procedure RecievedSerialNumbersPickup(Result, ExtendedParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Result) = type("Array") Then
		For Each Str In Result Do
			
			Items.SerialNumbersNew.AddRow();
			CurrentData = Items.SerialNumbersNew.CurrentData;
			CurrentData.NewNumber = Str;
			CurrentData.SerialNumber = Str;
			
		EndDo; 
	Else
		Items.SerialNumbersNew.AddRow();
		CurrentData = Items.SerialNumbersNew.CurrentData;
		CurrentData.NewNumber = Result;
		CurrentData.SerialNumber = Result;
	EndIf;
	
	Items.SerialNumbersNew.EndEditRow(False);	
	
EndProcedure

#EndRegion

#Region SearchByBarcode

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("ru = 'Введите штрихкод'; en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, ExtendedParameters) Export
    
    CurBarcode = ?(Result = Undefined, ExtendedParameters.CurBarcode, Result);
    
    
    If NOT IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
    EndIf;

EndProcedure

&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			If NOT ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			BarcodeData.Insert("ProductsAndServicesType", BarcodeData.ProductsAndServices.ProductsAndServicesType);
			If ValueIsFilled(BarcodeData.MeasurementUnit)
				AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
				BarcodeData.Insert("Ratio", BarcodeData.MeasurementUnit.Ratio);
			Else
				BarcodeData.Insert("Ratio", 1);
			EndIf;
		EndIf;
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	IncorrectBarcodesType = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("FilterProductsAndServicesType", PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));

	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
		   
		    CurBarcode.Insert("ProductsAndServices", ProductsAndServices);
			CurBarcode.Insert("Characteristic", Characteristic);
			CurBarcode.Insert("Batch", Batch);
			CurBarcode.Insert("MeasurementUnit", MeasurementUnit);
			UnknownBarcodes.Add(CurBarcode);
			
		ElsIf StructureData.FilterProductsAndServicesType <> BarcodeData.ProductsAndServicesType Then
			IncorrectBarcodesType.Add(New Structure("Barcode,ProductsAndServices,ProductsAndServicesType", CurBarcode.Barcode, BarcodeData.ProductsAndServices, BarcodeData.ProductsAndServicesType));
		ElsIf NOT (BarcodeData.ProductsAndServices = ProductsAndServices AND BarcodeData.Characteristic = Characteristic 
			AND BarcodeData.Batch = Batch AND BarcodeData.MeasurementUnit = MeasurementUnit) Then
			
			MessageString = NStr("ru = 'Считанный штрихкод привязан к другой номенклатуре: %1% %2% %3% %4%'; en = 'Read barcode associated with other products and services: %1% %2% %3% %4%'");
			MessageString = StrReplace(MessageString, "%1%", BarcodeData.ProductsAndServices);
			MessageString = StrReplace(MessageString, "%2%", BarcodeData.Characteristic);
			MessageString = StrReplace(MessageString, "%3%", BarcodeData.Batch);
			MessageString = StrReplace(MessageString, "%4%", BarcodeData.MeasurementUnit);
			CommonUseClientServer.MessageToUser(MessageString);
			
		Else
			NewRow = Object.SerialNumbers.Add();
			NewRow.SerialNumber = BarcodeData.SerialNumber;
			NewRow.NewNumber = CurBarcode.Barcode;
		EndIf;
	EndDo;
	
	Return New Structure("UnknownBarcodes, IncorrectBarcodesType",UnknownBarcodes, IncorrectBarcodesType);
	
EndFunction // FillByBarcodesData()

&AtClient
Procedure BarcodesReceived(BarcodesData) Export
	
	Modified = True;
	
	MissingBarcodes		= FillByBarcodesData(BarcodesData);
	UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
	IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
	
	ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure // BarcodesReceived()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		MissingBarcodes		= FillByBarcodesData(BarcodesArray);
		UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
		IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
		ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%'; en = 'Data by barcode is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Count);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ReceivedIncorrectBarcodesType(IncorrectBarcodesType) Export
	
	For Each CurhInvalidBarcode In IncorrectBarcodesType Do
		
		MessageString = NStr("ru = 'Найденная по штрихкоду %1% номенклатура -%2%- имеет тип %3%, который не подходит для этой табличной части'; en = 'Product %2% founded by barcode %1% have type %3% which is not suitable for this table section'");
		MessageString = StrReplace(MessageString, "%1%", CurhInvalidBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurhInvalidBarcode.ProductsAndServices);
		MessageString = StrReplace(MessageString, "%3%", CurhInvalidBarcode.ProductsAndServicesType);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	CurrentData = Items.SerialNumbersNew.CurrentData;
	If CurrentData <> Undefined Then
		CurrentRowID = CurrentData.GetID(); 	
	Else
		CurrentRowID = Undefined;
	EndIf;

EndProcedure

#EndRegion