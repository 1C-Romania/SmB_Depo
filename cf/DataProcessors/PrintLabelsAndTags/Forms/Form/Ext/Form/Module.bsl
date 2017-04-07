
// <Function description>
//
// Parameters
//  <Parameter1>  - <Type.Kind> - <parameter
//                 description> <parameter description
//  continuation> <Parameter2>  - <Type.Kind> - <parameter
//                 description> <parameter description continuation>
//
// Returns:
//   <Type.Kind>   - <returned value description>
//
Function SetDCSFilterItem(SettingsComposer, ParameterName, ParameterValue, Use = True)

	FoundItem = Undefined;
	
	Field = New DataCompositionField(ParameterName);
	
	Filter = SettingsComposer.Settings.Filter;
	For Each FilterItem IN Filter.Items Do
		If FilterItem.LeftValue = Field Then
			FoundItem = FilterItem;
		EndIf;
	EndDo;
	
	If FoundItem = Undefined Then
		FoundItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	EndIf;
	
	If TypeOf(ParameterValue) = Type("Array") Then
		FoundItem.ComparisonType = DataCompositionComparisonType.InList;
		ValueList = New ValueList;
		ValueList.LoadValues(ParameterValue);
		RightValue = ValueList;
	Else
		FoundItem.ComparisonType = DataCompositionComparisonType.Equal;
		RightValue = ParameterValue;
	EndIf;
	
	FoundItem.Use  = Use;
	FoundItem.LeftValue  = Field;
	FoundItem.RightValue = RightValue;
	
	Return FoundItem;

EndFunction // FindFilterItemDCS()

// Procedure imports filter settings from the default settings.
//
&AtServer
Procedure ImportFilterSettingsByDefault()
	
	DataCompositionSchema = DataProcessors.PrintLabelsAndTags.GetTemplate("TemplateFields");
	SettingsComposer.Initialize(
		New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, ThisForm.UUID))
	);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
EndProcedure // ImportFilterSettingsByDefault()

// Form OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// The PrintingParameter parameter is created as error bypass of platform 8.3.5. on creating the form attribute.
	
	ImportFilterSettingsByDefault();
	
	If ValueIsFilled(Parameters.AddressInStorage) Then
		
		DataStructure = GetFromTempStorage(Parameters.AddressInStorage);
		
		Object.SourceData.Load(DataStructure.Inventory);
		
		If ValueIsFilled(DataStructure.ActionsStructure) Then
			
			ActionParameter = Undefined;
			
			If DataStructure.ActionsStructure.Property("FillCompany", ActionParameter) Then
				Object.Company = ActionParameter;
			EndIf;
			
			If DataStructure.ActionsStructure.Property("FillWarehouse", ActionParameter) Then
				SetDCSFilterItem(SettingsComposer, "StructuralUnit", ActionParameter, True);
			EndIf;
			
			If DataStructure.ActionsStructure.Property("FillKindPrices", ActionParameter) Then
				Object.PriceKind = ActionParameter;
			EndIf;
			
			If DataStructure.ActionsStructure.Property("ShowColumnNumberOfDocument", ActionParameter) Then
				Items.InventoryDocumentQuantity.Visible = ActionParameter;
			EndIf;
			
			If DataStructure.ActionsStructure.Property("SetPrintModeFromDocument", ActionParameter) Then
				PrintFromDocument = True;
				Items.Settings.Visible = False;
			EndIf;
			
			FillLabelsQuantityByDocument        = DataStructure.ActionsStructure.Property("FillLabelsQuantityByDocument", ActionParameter);
			FillLabelsQuantityOnInventory = DataStructure.ActionsStructure.Property("FillLabelsQuantityOnInventory", ActionParameter);
			FillOutPriceTagsQuantityOnDocument        = DataStructure.ActionsStructure.Property("FillOutPriceTagsQuantityOnDocument", ActionParameter);
			FillPriceTagsQuantityOnInventory = DataStructure.ActionsStructure.Property("FillPriceTagsQuantityOnInventory", ActionParameter);
			
			If DataStructure.ActionsStructure.Property("FillProductsTable", ActionParameter) Then
				FillProductsTableAtServer(False);
			EndIf;
			
			If DataStructure.ActionsStructure.Property("SetMode", ActionParameter) Then
				SetMode(ActionParameter);
			Else
				Raise NStr("en='Print mode is not set';ru='Режим печати не установлен'");;
			EndIf;
			
		EndIf;
		
	Else
		
		// DataProcessor Call from interface
		FillLabelsQuantityByDocument        = False;
		FillLabelsQuantityOnInventory = True;
		FillOutPriceTagsQuantityOnDocument        = False;
		FillPriceTagsQuantityOnInventory = True;
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Object.Company = SettingValue;
		Else
			Object.Company = Catalogs.Companies.MainCompany;
		EndIf;
		
		If Constants.AccountingBySubsidiaryCompany.Get() Then
			Object.Company = Constants.SubsidiaryCompany.Get();
		EndIf;
		
		SetModeTagsPrintingAndLabelsAtServer();
		
	EndIf;
	
	If FillPriceTagsQuantityOnInventory
	AND Not FillOutPriceTagsQuantityOnDocument Then
		FillingModePriceLabelRadioButton = "Fill in with balances";
	EndIf;
	
	If Not FillPriceTagsQuantityOnInventory
	AND FillOutPriceTagsQuantityOnDocument Then
		FillingModePriceLabelRadioButton = "Fill out from document";
	EndIf;
	
	If Not FillPriceTagsQuantityOnInventory
	AND Not FillOutPriceTagsQuantityOnDocument Then
		FillingModePriceLabelRadioButton = "Do not fill";
	EndIf;
	
	If FillLabelsQuantityOnInventory
	AND Not FillLabelsQuantityByDocument Then
		FillingModeTagsRadioButton = "Fill in with balances";
	EndIf;
	
	If Not FillLabelsQuantityOnInventory
	AND FillLabelsQuantityByDocument Then
		FillingModeTagsRadioButton = "Fill out from document";
	EndIf;
	
	If Not FillLabelsQuantityOnInventory
	AND Not FillLabelsQuantityByDocument Then
		FillingModeTagsRadioButton = "Do not fill";
	EndIf;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// COMMAND HANDLERS

&AtClient
Function ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal)
	
	If Quantity < CountTotal Then
		
		Text = Text
		        + ?(Text <> "", Chars.LF, "")
		        + NStr("en='Selection mark is set for %QuantitySelected% strings from %QuantityTotal%.';ru='Отметка выбора установлена для %КоличествоВыбранных% строк из %КоличествоВсего%.'");
	
		Text = Text
		        + Chars.LF
		        + NStr("en='Check:either the quantity is not filled or the price tag (label) template is not specified. IN this case the selection mark for strings can not be specified.';ru='Проверьте: не заполнены либо количество, либо не задан шаблон ценника (этикетки). В этом случае отметка выбора для строк не может быть установлена.'");
	
		Text = StrReplace(Text, "%QuantitySelected%", Quantity);
		Text = StrReplace(Text, "%QuantityTotal%", CountTotal);
		
		ShowUserNotification("Operation completed", ,Text);
	
	EndIf;
	
EndFunction // GetCheckText()

// Procedure is opened by clicking the Select payments button.
//
&AtClient
Procedure ChooseLines()
	
	Quantity = 0;
	
	For Each TSRow IN Object.Inventory Do
		
		TSRow.Selected = CheckProductChoicePossibility(TSRow, Mode);
		
		If TSRow.Selected Then
			Quantity = Quantity + 1;
		EndIf;
		
	EndDo;
	
	CountTotal = Object.Inventory.Count();
	
	ShowUserAlertAboutPossibleError("", Quantity, CountTotal);
	
EndProcedure // ChooseStrings()

// Procedure is opened by clicking the Exclude payment request button.
//
&AtClient
Procedure ExcludeRows()
	
	For Each TSRow IN Object.Inventory Do
		TSRow.Selected = False
	EndDo;
	
EndProcedure // ExcludeStrings()

// Procedure is opened by clicking the Select predefined payments button.
//
&AtClient
Procedure ChooseHighlightedLines(Command)
	
	Quantity = 0;
	
	RowArray = Items.Inventory.SelectedRows;
	For Each LineNumber IN RowArray Do
		
		TSRow = Object.Inventory.FindByID(LineNumber);
		TSRow.Selected = CheckProductChoicePossibility(TSRow, Mode);
		
		If TSRow.Selected Then
			Quantity = Quantity + 1;
		EndIf;
		
	EndDo;
	
	CountTotal = RowArray.Count();
	
	ShowUserAlertAboutPossibleError("", Quantity, CountTotal);
	
EndProcedure // SelectHighlightedStrings()

// Procedure is opened by clicking the Delete selected payments button.
//
&AtClient
Procedure ExcludeSelectedRows(Command)
	
	RowArray = Items.Inventory.SelectedRows;
	For Each LineNumber IN RowArray Do
		TSRow = Object.Inventory.FindByID(LineNumber);
		TSRow.Selected = False;
	EndDo;
	
EndProcedure // ExcludeSelectedRows()

// Procedure fills out the Inventory tabular section.
//
&AtServer
Procedure FillProductsTableAtServer(CheckFilling = True)
	
	If CheckFilling AND ThisForm.CheckFilling() = False Then
		Return;
	EndIf;
	
	// Necessary fields for output in the products table on a form.
	SettingsStructure = DataProcessors.PrintLabelsAndTags.GetEmptySettingsStructure();
	
	SettingsStructure.MandatoryFields.Add("Price");
	SettingsStructure.MandatoryFields.Add("Barcode");
	SettingsStructure.MandatoryFields.Add("Quantity");
	SettingsStructure.MandatoryFields.Add("ProductsAndServices");
	If GetFunctionalOption("UseCharacteristics") Then
		SettingsStructure.MandatoryFields.Add("Characteristic");
	EndIf;
	If GetFunctionalOption("UseBatches") Then
		SettingsStructure.MandatoryFields.Add("Batch");
	EndIf;
	SettingsStructure.MandatoryFields.Add("BalanceAtWarehouse");
	
	// Templates of labels and price tags.
	SettingsStructure.MandatoryFields.Add("ProductsAndServices.ProductsAndServicesKind.LabelTemplate");
	SettingsStructure.MandatoryFields.Add("ProductsAndServices.ProductsAndServicesKind.PriceTagsTemplate");
	
	SettingsStructure.DataParameters.Insert("PriceKind"    , Object.PriceKind);
	SettingsStructure.DataParameters.Insert("StructuralUnit", Object.StructuralUnit);
	SettingsStructure.DataParameters.Insert("Company", SmallBusinessServer.GetCompany(Object.Company));
	SettingsStructure.SettingsComposer = SettingsComposer;
	
	If Object.SourceData.Count() > 0 OR PrintFromDocument Then
		SettingsStructure.DataCompositionSchemaTemplateName = "TemplateFieldsDocument";
		SettingsStructure.SourceData = Object.SourceData.Unload();
	Else
		SettingsStructure.DataCompositionSchemaTemplateName = "DBTemplateFields";
	EndIf;
	
	Object.Inventory.Clear();
	
	// Import of the generated products list.
	ResultStructure = DataProcessors.PrintLabelsAndTags.PrepareDataStructure(SettingsStructure);
	For Each TSRow IN ResultStructure.ProductsTable Do
		
		NewRow = Object.Inventory.Add();
		NewRow.ProductsAndServices         = TSRow.ProductsAndServices;
		
		If GetFunctionalOption("UseCharacteristics") Then
			NewRow.Characteristic       = TSRow.Characteristic;
		EndIf;
		If GetFunctionalOption("UseBatches") Then
			NewRow.Batch             = TSRow.Batch;
		EndIf;
		
		NewRow.Price                 = TSRow.Price;
		NewRow.Barcode             = TSRow.Barcode;
		//NewString.PriceTagsTemplate        = TSRString[ResultStructure.AccordanceFieldsDCSProductsTableColumns.Get("ProductsAndServices.ProductsAndServicesKind.PriceTagsTemplate")];
		//NewString.LabelTemplate       = TSString[ResultStructure.AccordanceFieldsDCSProductsTableColumns.Get("ProductsAndServices.ProductsAndServicesKind.LabelTemplate")];
		NewRow.BalanceAtWarehouse      = TSRow.BalanceAtWarehouse;
		NewRow.QuantityInDocument = TSRow.Quantity;
		
		// Calculating Labels quantity.
		If FillLabelsQuantityByDocument AND Not FillLabelsQuantityOnInventory Then
			NewRow.LabelsQuantity = NewRow.QuantityInDocument;
		ElsIf FillLabelsQuantityByDocument AND FillLabelsQuantityOnInventory Then
			NewRow.LabelsQuantity = ?(NewRow.QuantityInDocument > NewRow.BalanceAtWarehouse,NewRow.BalanceAtWarehouse,NewRow.QuantityInDocument);
		ElsIf Not FillLabelsQuantityByDocument AND FillLabelsQuantityOnInventory Then
			NewRow.LabelsQuantity = ?(NewRow.BalanceAtWarehouse > 0, NewRow.BalanceAtWarehouse, 0);
		EndIf;
		
		// Calculation of Price Tags quantity.
		If FillOutPriceTagsQuantityOnDocument AND Not FillPriceTagsQuantityOnInventory Then
			NewRow.PriceTagsQuantity = 1;
		ElsIf FillOutPriceTagsQuantityOnDocument AND FillPriceTagsQuantityOnInventory Then
			NewRow.PriceTagsQuantity = ?(NewRow.BalanceAtWarehouse > 0, 1, 0);
		ElsIf Not FillOutPriceTagsQuantityOnDocument AND FillPriceTagsQuantityOnInventory Then
			NewRow.PriceTagsQuantity = ?(NewRow.BalanceAtWarehouse > 0, 1, 0);
		EndIf;
		
		NewRow.Selected = CheckProductChoicePossibility(NewRow, Mode);
		
	EndDo;
	
	Items.Inventory.Refresh();
	
EndProcedure // FillProductsTableAtServer()

// Procedure - command handler "FillProductsTable".
//
&AtClient
Procedure FillInventoryTable(Command)
	
	QuestionText = NStr("en='All manually entered data will be lost. Do you want to continue?';ru='При перезаполнении все введенные вручную данные будут потеряны, продолжить?'");
	ShowQueryBox(New NotifyDescription("FillInventoryTableEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure FillInventoryTableEnd(Result, AdditionalParameters) Export
    
    If Object.Inventory.Count() = 0 OR DialogReturnCode.Yes = Result Then
        FillProductsTableAtServer();
    EndIf;

EndProcedure // FillProductsTable()

// Procedure - handler of the Print command
//
&AtClient
Procedure Print(Command)
	
	SelectedRows = Object.Inventory.FindRows(New Structure("Selected", True));
	
	If SelectedRows.Count() = 0 Then
		
		ShowMessageBox(Undefined,NStr("en='No items selected';ru='Не выбрано ни одного товара'"));
		Return;
		
	EndIf;
	
	If ThisForm.CheckFilling() Then
		
		PrintInfo = New Array;   // Add labels and price tags dataprocessor printing object in the printing parameters array.
		PrintInfo.Add(Object); // We will access the object using CommandParameter[0]
		
		TemplateNames = "";
		
		If Mode = "TagsAndLabePrinting" Then
			IsPriceLabelsNumber = False;
			IsPriceTagTemplate = False;
			IsTagNumber = False;
			IsTagTemplate = False;
			For Each CurRow IN SelectedRows Do
				If CurRow.PriceTagsQuantity > 0 Then
					IsPriceLabelsNumber = True;
				EndIf;
				If ValueIsFilled(CurRow.PriceTagsTemplate) Then
					IsPriceTagTemplate = True;
				EndIf;
				If CurRow.LabelsQuantity > 0 Then
					IsTagNumber = True;
				EndIf;
				If ValueIsFilled(CurRow.LabelTemplate) Then
					IsTagTemplate = True;
				EndIf;
			EndDo;
			If IsPriceLabelsNumber
			   AND IsPriceTagTemplate
			   AND IsTagNumber
			   AND IsTagTemplate Then
				TemplateNames = "Price Tags,Labels";
			ElsIf IsTagNumber
			   AND IsTagTemplate Then
				TemplateNames = "Labels";
			Else
				TemplateNames = "Price Tags";
			EndIf;
		ElsIf Mode = "TagsPrinting" Then
			TemplateNames = "Price Tags";
		ElsIf Mode = "LabelsPrinting" Then
			TemplateNames = "Labels";
		EndIf;
		
		PrintParameters =New Structure;
		PrintParameters.Insert("FormTitle", NStr("en='Print labels and tags';ru='Печать этикеток и ценников'"));
		PrintParameters.Insert("PrintInfo", PrintInfo);
		
		CommandParameter = New Array;
		CommandParameter.Add(PredefinedValue("Catalog.LabelsAndTagsTemplates.EmptyRef"));
		
		PrintManagementClient.ExecutePrintCommand("DataProcessor.PrintLabelsAndTags", TemplateNames, CommandParameter, ThisForm, PrintParameters);
		
	EndIf;
	
EndProcedure // Print()

// Procedure - form OnSaveDataInSettingsAtServer event hadler.
//
&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	If SavedSettings <> Undefined Then
		
		For Each KeyAndValue IN SavedSettings Do
			// Inverse name conversion for map key storage in the structure
			KeyName = StrReplace(KeyAndValue.Key,"_QTQ_",".");
			KeyName = StrReplace(KeyName,"_QPQ_"," ");
			If KeyName = "_QQQ_" Then
				KeyName = "";
			EndIf;
			Settings.Insert(KeyName, KeyAndValue.Value);
		EndDo;
		
	Else
		
		// Filter is saved only if it is not print from document
		Settings.Insert("SettingsOFFilter",New ValueStorage(SettingsComposer.Settings));
		
	EndIf;
	
EndProcedure // OnSaveDataInSettingsAtServer()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("AddressInStorage") AND ValueIsFilled(Parameters.AddressInStorage) Then
		
		SavedSettings = New Structure;
		For Each KeyAndValue IN Settings Do
			// Conversion of a name for map key storage in the structure
			KeyName = StrReplace(KeyAndValue.Key,".","_QTQ_");
			KeyName = StrReplace(KeyName," ","_QPQ_");
			If KeyName = "" Then
				KeyName = "_QQQ_";
			EndIf;
			SavedSettings.Insert(KeyName, KeyAndValue.Value);
		EndDo;
		
		Settings.Clear();
		
	Else
		
		
		SettingsOFFilter = Settings.Get("SettingsOFFilter");
		If SettingsOFFilter <> Undefined Then
			SettingsComposer.LoadSettings(SettingsOFFilter.Get());
		Else
			ImportFilterSettingsByDefault();
		EndIf;
		
		Mode = Settings.Get("Mode");
		If ValueIsFilled(Mode) Then
			SetMode(Mode);
		EndIf;
		
	EndIf;
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClientAtServerNoContext
Function CheckProductChoicePossibility(CurrentData, Mode)
	
	If Mode = "TagsAndLabePrinting" Then
	
		If (CurrentData.PriceTagsQuantity = 0)
			AND CurrentData.LabelsQuantity = 0 Then
			
			Return False;
			
		ElsIf Not ValueIsFilled(CurrentData.PriceTagsTemplate)
			AND Not ValueIsFilled(CurrentData.LabelTemplate) Then
			
			Return False;
			
		ElsIf (ValueIsFilled(CurrentData.PriceTagsTemplate)
			      AND Not ValueIsFilled(CurrentData.LabelTemplate)
			      AND CurrentData.LabelsQuantity <> 0
			      AND CurrentData.PriceTagsQuantity = 0) Then

			Return False;
			
		ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
			      AND ValueIsFilled(CurrentData.LabelTemplate)
			      AND CurrentData.LabelsQuantity = 0
			      AND CurrentData.PriceTagsQuantity <> 0) Then
			
			Return False;
			
		Else
			
			Return True;
			
		EndIf;
	
	ElsIf Mode = "LabelsPrinting" Then
		
		If CurrentData.LabelsQuantity = 0 OR Not ValueIsFilled(CurrentData.LabelTemplate) Then
			Return False;
		Else
			Return True;
		EndIf;
		
	ElsIf Mode = "TagsPrinting" Then
		
		If CurrentData.PriceTagsQuantity = 0 OR Not ValueIsFilled(CurrentData.PriceTagsTemplate) Then
			Return False;
		Else
			Return True;
		EndIf;
		
	EndIf;
	
EndFunction // CheckProductChoicePossibility()

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	CellName = Item.CurrentItem.Name;
	If CellName = "InventoryProductsAndServices" or CellName = "InventoryCharacteristic" 
		or CellName = "InventoryBatch" Then
	
		ShowValue(,Items.Inventory.CurrentData.ProductsAndServices);
	
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the PriceTagsQuantity fields of the Inventory tabular section.
//
&AtClient
Procedure InventoryPriceTagsQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure // InventoryPriceTagsQuantityOnChange()

// Procedure - handler of the OnChange event of the LabelsQuantity field of the Inventory tabular section.
//
&AtClient
Procedure InventoryLabelsQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure // InventoryLabelsQuantityOnChange()

// Procedure - handler of the OnChange event of the PriceTagTemplate field of the Inventory tabular section.
//
&AtClient
Procedure InventoryPriceTagsTemplateOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure // InventoryPriceTagsTemplateOnChange()

// Procedure - handler of the OnChange event of the LabelTemplate field of the Inventory tabular section.
//
&AtClient
Procedure InventoryLabelTemplateOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Selected = CheckProductChoicePossibility(CurrentData, Mode);
	
EndProcedure // InventoryLabelsTemplateOnChange()

// Procedure - handler of the OnChange event of the Selected field of the Inventory tabular section.
//
&AtClient
Procedure InventoryChosenOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentRow = CurrentData.LineNumber - 1;
	
	If CurrentData.Selected Then
		
		ClearMessages();
		
		CurrentData.Selected = True;
		
		If Mode = "TagsAndLabePrinting" Then
			
			If (ValueIsFilled(CurrentData.PriceTagsTemplate)
					AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					AND Not ValueIsFilled(CurrentData.LabelTemplate)
					AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en='The price tags number is not filled';ru='Не заполнено количество ценников'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND    ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en='The price tags template is not selected';ru='Не выбран шаблон ценника'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND    ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en='The labels number is not filled';ru='Не заполнено количество этикеток'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND    ValueIsFilled(CurrentData.LabelsQuantity)) Then
					
				Message = New UserMessage;
				Message.Text = NStr("en='No label template selected';ru='Не выбран шаблон этикетки'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (   ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND    ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='Price tags and (or) labels quantity is not filled';ru='Не заполнено количество ценников и(или) этикеток'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND    ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND    ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='Price tags and(or) labels templates are not selected';ru='Не выбраны шаблоны ценников и(или) этикеток'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='Price tags and (or) labels quantity is not filled';ru='Не заполнено количество ценников и(или) этикеток'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (   ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND Not ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND Not ValueIsFilled(CurrentData.LabelTemplate)
					 AND    ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='The number of price tags and (or) the label template is not filled';ru='Не заполнено количество ценников и(или) шаблон этикетки'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			ElsIf (NOT ValueIsFilled(CurrentData.PriceTagsTemplate)
					 AND    ValueIsFilled(CurrentData.PriceTagsQuantity)
					 AND    ValueIsFilled(CurrentData.LabelTemplate)
					 AND Not ValueIsFilled(CurrentData.LabelsQuantity)) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='The number of labels and (or) the price tag template is not filled';ru='Не заполнено количество этикеток и(или) шаблон ценника'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
		ElsIf Mode = "LabelsPrinting" Then
			
			If CurrentData.LabelsQuantity = 0 Then
			
				Message = New UserMessage;
				Message.Text = NStr("en='The labels number is not filled';ru='Не заполнено количество этикеток'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
			If Not ValueIsFilled(CurrentData.LabelTemplate) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='No label template selected';ru='Не выбран шаблон этикетки'");
				Message.Field = "Object.Products["+CurrentRow+"].LabelTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
		ElsIf Mode = "TagsPrinting" Then
			
			If CurrentData.PriceTagsQuantity = 0 Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='The price tags number is not filled';ru='Не заполнено количество ценников'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsQuantity";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
			If Not ValueIsFilled(CurrentData.PriceTagsTemplate) Then
				
				Message = New UserMessage;
				Message.Text = NStr("en='The price tags template is not selected';ru='Не выбран шаблон ценника'");
				Message.Field = "Object.Products["+CurrentRow+"].PriceTagsTemplate";
				Message.Message();
				
				CurrentData.Selected = False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // InventorySelectedOnChange()

// Procedure - handler of the SetPriceTagsQuantity command.
//
&AtClient
Procedure SetPriceTagsQuantity(Command)
	
	ValueSelected = Undefined;
	ShowInputNumber(New NotifyDescription("SetPriceTagsQuantityEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, NStr("en='Enter the number of the price tags';ru='Введите количество ценников'"), 10, 2);
	
EndProcedure

&AtClient
Procedure SetPriceTagsQuantityEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber IN RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.PriceTagsQuantity  = ValueSelected;
            TSRow.Selected              = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en='Price tags quantity %Quantity% specified.';ru='Установлено количество ценников %Количество%.'");
        Text = StrReplace(Text, "%Quantity%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure // SetPriceTagsCount()

// Procedure - handler of the SetLabelsQuantity command.
//
&AtClient
Procedure SetLabelsQuantity(Command)
	
	ValueSelected = Undefined;
	ShowInputNumber(New NotifyDescription("SetLabelsQuantityEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, "Input quantity", 10, 2);
	
EndProcedure

&AtClient
Procedure SetLabelsQuantityEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber IN RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.LabelsQuantity  = ValueSelected;
            TSRow.Selected              = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en='Labels  quantity %Quantity% specified.';ru='Установлено количество этикеток %Количество%.'");
        Text = StrReplace(Text, "%Quantity%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure // SetLabelsCount()

// Procedure - handler of the SetPriceTagsTemplate command.
//
&AtClient
Procedure SetPriceTagsTemplate(Command)
	
	ValueSelected = Undefined;
	ShowInputValue(New NotifyDescription("SetPriceTagsTemplateEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, "Choosing the price tag template", Type("CatalogRef.LabelsAndTagsTemplates"));
	
EndProcedure

&AtClient
Procedure SetPriceTagsTemplateEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber IN RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.PriceTagsTemplate  = ValueSelected;
            TSRow.Selected         = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en='The %Template% template specified.';ru='Установлен шаблон ""%Шаблон%"".'");
        Text = StrReplace(Text, "%Pattern%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure // SetPriceTagsTemplate()

// Procedure - handler of the SetLabelsTemplate command.
//
&AtClient
Procedure SetLabelsTemplate(Command)
	
	ValueSelected = Undefined;
	ShowInputValue(New NotifyDescription("SetLabelsTemplateEnd", ThisObject, New Structure("ValueSelected", ValueSelected)), ValueSelected, "Choosing label template", Type("CatalogRef.LabelsAndTagsTemplates"));
	
EndProcedure

&AtClient
Procedure SetLabelsTemplateEnd(Result, AdditionalParameters) Export
    
    ValueSelected = ?(Result = Undefined, AdditionalParameters.ValueSelected, Result);
    
    
    If (Result <> Undefined) Then
        
        Quantity = 0;
        
        RowArray = Items.Inventory.SelectedRows;
        For Each LineNumber IN RowArray Do
            TSRow = Object.Inventory.FindByID(LineNumber);
            TSRow.LabelTemplate = ValueSelected;
            TSRow.Selected         = CheckProductChoicePossibility(TSRow, Mode);
            
            If TSRow.Selected Then
                Quantity = Quantity + 1;
            EndIf;
            
        EndDo;
        
        CountTotal = RowArray.Count();
        
        Text = NStr("en='The %Template% template specified.';ru='Установлен шаблон ""%Шаблон%"".'");
        Text = StrReplace(Text, "%Pattern%", ValueSelected);
        
        ShowUserAlertAboutPossibleError(Text, Quantity, CountTotal);
        
    EndIf;

EndProcedure // SetLabelsTemplate()

////////////////////////////////////////////////////////////////////////////////
// PRINTING MODE CONTROL

// Procedure sets items visible according to form parameters setting
//
&AtServer
Procedure RefreshElementsVisible()
	
	TagVisible = False;
	PriceTagVisible  = False;
		
	If Mode = "TagsAndLabePrinting" Then
		TagVisible = True;
		PriceTagVisible  = True;
	ElsIf Mode = "TagsPrinting" Then
		TagVisible = False;
		PriceTagVisible  = True;
	ElsIf Mode = "LabelsPrinting" Then
		TagVisible = True;
		PriceTagVisible  = False;
	EndIf;
	
	If PrintFromDocument Then
		Items.FillLabelsQuantityOnInventory.Visible = False;
		Items.FillingModeTagsRadioButton.Visible = TagVisible;
	Else
		Items.FillLabelsQuantityOnInventory.Visible = TagVisible;
		Items.FillingModeTagsRadioButton.Visible = False;
	EndIf;
	
	Items.InventoryTagsNumber.Visible               = TagVisible;
	Items.InventoryTagTemplate.Visible                   = TagVisible;
	Items.InventorySetLabelsTemplate.Visible         = TagVisible;
	Items.InventorySetLabelsNumber.Visible     = TagVisible;
	
	If PrintFromDocument Then
		Items.FillPriceTagsQuantityOnInventory.Visible = False;
		Items.FillingModePriceLabelRadioButton.Visible = PriceTagVisible;
	Else
		Items.FillPriceTagsQuantityOnInventory.Visible = PriceTagVisible;
		Items.FillingModePriceLabelRadioButton.Visible = False;
	EndIf;
	
	Items.InventoryPriceTagsNumber.Visible               = PriceTagVisible;
	Items.InventoryPriceTagTemplate.Visible                    = PriceTagVisible;
	Items.InventorySetPriceTagsTemplate.Visible         = PriceTagVisible;
	Items.InventorySetToStickersNumber.Visible     = PriceTagVisible;
	
	For Each CurRow IN Object.Inventory Do
		CurRow.Selected = CheckProductChoicePossibility(CurRow, Mode);
	EndDo;
	
EndProcedure // RefreshElementsVisible()

// Procedure sets the PriceTagsPrinting mode on the server.
//
&AtServer
Procedure SetModeTagsPrintingAtServer()
	
	AutoTitle = False;
	Mode = "TagsPrinting";
	
	If PrintFromDocument Then
		Title = "Price tags printing from document";
	Else
		Title = "Tags printing";
	EndIf;
	
	RefreshElementsVisible();
	
EndProcedure // SetModeTagsPrintingAtServer()

// Procedure - handler of the SetPriceTagsPrintingMode command.
//
&AtClient
Procedure SetModeTagsPrinting(Command)
	
	SetModeTagsPrintingAtServer();
	
EndProcedure // SetPriceTagsPrintingMode()

// Procedure sets the PriceTagsAndLabelsPrinting mode on the server.
//
&AtServer
Procedure SetModeTagsPrintingAndLabelsAtServer()
	
	AutoTitle = False;
	Mode = "TagsAndLabePrinting";
	
	If PrintFromDocument Then
		Title = "Printing labels and price tags from document";
	Else
		Title = "Print labels and tags";
	EndIf;
	
	RefreshElementsVisible();
	
EndProcedure // SetPriceTagsAndLabelsPrintingModeAtServer()

// Procedure - handler of the SetPriceTagsAndLabelsPrintingMode command.
//
&AtClient
Procedure SetModeTagsAndLabelsPrinting(Command)
	
	SetModeTagsPrintingAndLabelsAtServer();
	
EndProcedure // SetModeTagsAndLabelsPrinting()

// Procedure sets the LabelsPrinting mode on the server.
//
&AtServer
Procedure SetModeLabelsPrintingAtServer()
	
	AutoTitle = False;
	Mode = "LabelsPrinting";
	
	If PrintFromDocument Then
		Title = "Labels printing from document";
	Else
		Title = "Labels printing";
	EndIf;
	
	RefreshElementsVisible();
	
EndProcedure // SetLabelsPrintingModeAtServer()

// Procedure - handler of the SetLabelsPrintingMode command.
//
&AtClient
Procedure SetModeLabelsPrinting(Command)
	
	SetModeLabelsPrintingAtServer();
	
EndProcedure // SetLabelsPrintingMode()

// Procedure sets the selected print mode
//
// Parameters
//  <Parameter1>  - <Type.Kind> - <parameter
//                 description> <parameter description
//  continuation> <Parameter2>  - <Type.Kind> - <parameter
//                 description> <parameter description continuation>
//
&AtServer
Procedure SetMode(RegimeParameter)
	
	If RegimeParameter = "TagsAndLabePrinting" Then
		SetModeTagsPrintingAndLabelsAtServer();
	ElsIf RegimeParameter = "TagsPrinting" Then
		SetModeTagsPrintingAtServer();
	ElsIf RegimeParameter = "LabelsPrinting" Then
		SetModeLabelsPrintingAtServer();
	Else
		Raise NStr("en='Set print mode is not supported';ru='Установленный режим печати не поддерживается'");
	EndIf;
	
EndProcedure // SetMode()

&AtClient
Procedure FillingModePriceLabelRadioButtonOnChange(Item)
	
	If FillingModePriceLabelRadioButton = "Fill in with balances" Then
		FillPriceTagsQuantityOnInventory = True;
		FillOutPriceTagsQuantityOnDocument = False;
	ElsIf FillingModePriceLabelRadioButton = "Fill out from document" Then
		FillPriceTagsQuantityOnInventory = False;
		FillOutPriceTagsQuantityOnDocument = True;
	Else
		FillPriceTagsQuantityOnInventory = False;
		FillOutPriceTagsQuantityOnDocument = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillingModeTagsRadioButtonOnChange(Item)
	
	If FillingModeTagsRadioButton = "Fill in with balances" Then
		FillLabelsQuantityOnInventory = True;
		FillLabelsQuantityByDocument = False;
	ElsIf FillingModeTagsRadioButton = "Fill out from document" Then
		FillLabelsQuantityOnInventory = False;
		FillLabelsQuantityByDocument = True;
	Else
		FillLabelsQuantityOnInventory = False;
		FillLabelsQuantityByDocument = False;
	EndIf;
	
EndProcedure



