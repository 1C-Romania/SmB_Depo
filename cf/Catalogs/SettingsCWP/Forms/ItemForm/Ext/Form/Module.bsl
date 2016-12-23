&AtClient
Var CachedValues;

// Stores Button Accelerator for editing
&AtClient
Var OldAccelerator;

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillInButtonsTableFromLayout();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("CWPSettingChanged", Object.Ref);
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtClient
Procedure ShortcutSelectionStartEnd(Result, AdditionalParameters) Export

	If Result <> Undefined Then
		
		CurrentData = AdditionalParameters.CurrentData;
		
		ClearShortcut(Result, CurrentData);
		
		FillPropertyValues(CurrentData, Result);
		Modified = True;
		
		CurrentData.Shortcut = ShortcutPresentation(Result, True);
		
		If AdditionalParameters.TSName = "LowerBarButtons" Then
			If CurrentData.Shortcut <> CurrentData.ShortcutPreviousValue Then
				CurrentData.ButtonTitle = StrReplace(CurrentData.ButtonTitle, "("+TrimAll(CurrentData.ShortcutPreviousValue)+")", "("+TrimAll(CurrentData.Shortcut)+")");
				CurrentData.ShortcutPreviousValue = CurrentData.Shortcut;
			EndIf;
		EndIf;
		
	EndIf;

EndProcedure

// The procedure clears the data of the key combination in the current line of the tabular section transferred through the parameter.
//
&AtClient
Procedure ClearShortcut(Shortcut, CurrentData)
	
	ShortcutPresentation = ShortcutPresentation(Shortcut);
	CurrentData.Key = String(Key.No);
	CurrentData.Ctrl = False;
	CurrentData.Shift = False;
	CurrentData.Alt = False;
	CurrentData.Shortcut = "";
	
EndProcedure

// The function returns
// the Parameters key presentation:
// ValueKey						- Key
//
// Returned
// value String - Key presentation
//
&AtClient
Function KeyPresentation(ValueKey) Export
	
	If String(Key._1) = String(ValueKey) Then
		Return "1";
	ElsIf String(Key._2) = String(ValueKey) Then
		Return "2";
	ElsIf String(Key._3) = String(ValueKey) Then
		Return "3";
	ElsIf String(Key._4) = String(ValueKey) Then
		Return "4";
	ElsIf String(Key._5) = String(ValueKey) Then
		Return "5";
	ElsIf String(Key._6) = String(ValueKey) Then
		Return "6";
	ElsIf String(Key._7) = String(ValueKey) Then
		Return "7";
	ElsIf String(Key._8) = String(ValueKey) Then
		Return "8";
	ElsIf String(Key._9) = String(ValueKey) Then
		Return "9";
	ElsIf String(Key.Num0) = String(ValueKey) Then
		Return "Num 0";
	ElsIf String(Key.Num1) = String(ValueKey) Then
		Return "Num 1";
	ElsIf String(Key.Num2) = String(ValueKey) Then
		Return "Num 2";
	ElsIf String(Key.Num3) = String(ValueKey) Then
		Return "Num 3";
	ElsIf String(Key.Num4) = String(ValueKey) Then
		Return "Num 4";
	ElsIf String(Key.Num5) = String(ValueKey) Then
		Return "Num 5";
	ElsIf String(Key.Num6) = String(ValueKey) Then
		Return "Num 6";
	ElsIf String(Key.Num7) = String(ValueKey) Then
		Return "Num 7";
	ElsIf String(Key.Num8) = String(ValueKey) Then
		Return "Num 8";
	ElsIf String(Key.Num9) = String(ValueKey) Then
		Return "Num 9";
	ElsIf String(Key.NumAdd) = String(ValueKey) Then
		Return "Num +";
	ElsIf String(Key.NumDecimal) = String(ValueKey) Then
		Return "Num .";
	ElsIf String(Key.NumDivide) = String(ValueKey) Then
		Return "Num /";
	ElsIf String(Key.NumMultiply) = String(ValueKey) Then
		Return "Num *";
	ElsIf String(Key.NumSubtract) = String(ValueKey) Then
		Return "Num -";
	Else
		Return String(ValueKey);
	EndIf;
	
EndFunction

// The function returns
// the Parameters key presentation:
// Shortcut						- Combination of keys that
// require WithoutBrackets presentation							- The flag indicating that the presentation shall be formed without brackets
//
// Returned
// value String - Key combination presentation
//
&AtClient
Function ShortcutPresentation(Shortcut, WithoutParentheses = False) Export
	
	If Shortcut.Key = Key.No Then
		Return "";
	EndIf;
	
	Description = ?(WithoutParentheses, "", "(");
	If Shortcut.Ctrl Then
		Description = Description + "Ctrl+"
	EndIf;
	If Shortcut.Alt Then
		Description = Description + "Alt+"
	EndIf;
	If Shortcut.Shift Then
		Description = Description + "Shift+"
	EndIf;
	Description = Description + KeyPresentation(Shortcut.Key) + ?(WithoutParentheses, "", ")");
	
	Return Description;
	
EndFunction

// The function returns
// the Parameters key presentation:
// Shortcut						- Combination of keys that
// require WithoutBrackets presentation							- The flag indicating that the presentation shall be formed without brackets
//
// Returned
// value String - Key combination presentation
//
&AtClient
Function ShortcutPresentationByElements(Key, Alt, Ctrl, Shift, WithoutParentheses = False) Export
	
	If Key = "" Then
		Return "";
	EndIf;
	
	Description = ?(WithoutParentheses, "", "(");
	If Ctrl Then
		Description = Description + "Ctrl+"
	EndIf;
	If Alt Then
		Description = Description + "Alt+"
	EndIf;
	If Shift Then
		Description = Description + "Shift+"
	EndIf;
	Description = Description + KeyPresentation(Key) + ?(WithoutParentheses, "", ")");
	
	Return Description;
	
EndFunction

// The function temporary stores the structure that contains ThisObject and returns address in the temporary storage.
//
&AtServer
Function AddressInTemporaryStorage()
	
	Return PutToTempStorage(
		New Structure(
			"QuickSale", ThisObject),
		UUID);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// The procedure fills in LowerBarButtonsActionsTable TS based on LowerBarButtonsStandardFunctions layout data.
//
&AtServer
Procedure FillInButtonsTableFromLayout()

	Template = Catalogs.SettingsCWP.GetTemplate("LowerBarButtonsStandardFunctions");
	
	TableLowerBarButtonsActions.Clear();
	
	LineNumbers = Template.TableHeight;
	
	For LayoutLineNumber = 2 To LineNumbers Do
		
		TableRow = TableLowerBarButtonsActions.Add();
		TableRow.ButtonPresentation = Template.Area(LayoutLineNumber,1,LayoutLineNumber,1).Text;
		TableRow.CommandName          = Template.Area(LayoutLineNumber,2,LayoutLineNumber,2).Text;
		TableRow.ButtonName           = Template.Area(LayoutLineNumber,3,LayoutLineNumber,3).Text;
		TableRow.ButtonTitle     = Template.Area(LayoutLineNumber,4,LayoutLineNumber,4).Text;
		TableRow.Key             = Template.Area(LayoutLineNumber,6,LayoutLineNumber,6).Text;
		TableRow.Alt      = Boolean(Template.Area(LayoutLineNumber,7,LayoutLineNumber,7).Text);
		TableRow.Ctrl     = Boolean(Template.Area(LayoutLineNumber,8,LayoutLineNumber,8).Text);
		TableRow.Shift    = Boolean(Template.Area(LayoutLineNumber,9,LayoutLineNumber,9).Text);
		TableRow.Default         = Boolean(Template.Area(LayoutLineNumber,10,LayoutLineNumber,10).Text);
		
	EndDo;
	
EndProcedure // FillInButtonsTableFromLayout()

#EndRegion

#Region EventsHandlersElementQuickSaleFormTable

// Procedure - StartChoice event handler in the column of table Parts Shortcut QuickSale forms.
//
&AtClient
Procedure QuickSaleShortcutStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.QuickSale.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure("CurrentData, TSName", CurrentData, "QuickSale");
	NotifyDescription = New NotifyDescription("ShortcutSelectionStartEnd", ThisObject, AdditionalParameters);
	OpenForm("Catalog.SettingsCWP.Form.FormShortcutSelection", 
		New Structure("Address, Workplace", AddressInTemporaryStorage(), Object.Workplace), 
		ThisObject, 
		UUID,
		,
		,
		NotifyDescription, 
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - Clearing event handler in Shortcut column of the form QuickSale tabular section.
//
&AtClient
Procedure QuickSaleShortcutClearing(Item, StandardProcessing)
	
	CurrentData = Items.QuickSale.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.Key = String(Key.No);
	CurrentData.Ctrl = False;
	CurrentData.Shift = False;
	CurrentData.Alt = False;
	CurrentData.Shortcut = "";
	
EndProcedure

#EndRegion

#Region EventsHandlersElementsTablesFormsLowerBarButtons

// Procedure - FillInByDefault command handler of forms.
//
&AtClient
Procedure Fill(Command)
	
	If Object.LowerBarButtons.Count()>0 Then
		
		QuestionText = NStr("en='Button table is filled in. Clear?';ru='Таблица кнопок заполнена. Очистить?'");
		
		NotificationHandler = New NotifyDescription("NotificationQueryClearButtonTable", ThisObject);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		FillInBottomPanelByDefaultClient();
	EndIf;

EndProcedure

// The procedure fills in LowerBarButtons TS based on LowerBarButtonsActionsTable TS data.
//
&AtClient
Procedure FillInBottomPanelByDefaultClient()
	
	Object.LowerBarButtons.Clear();
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Default", True);
	TableRows = TableLowerBarButtonsActions.FindRows(SearchStructure);
	
	For Each TableRow IN TableRows Do
		CurrentData = Object.LowerBarButtons.Add();
		FillPropertyValues(CurrentData, TableRow);
		
		CurrentData.Shortcut = ShortcutPresentationByElements(CurrentData.Key, CurrentData.Alt, CurrentData.Ctrl, CurrentData.Shift, True);
		CurrentData.ShortcutPreviousValue = CurrentData.Shortcut;
	EndDo;
	
EndProcedure

// The procedure processes the response to a query of cleaning TS LowerBarButtons.
//
&AtClient
Procedure NotificationQueryClearButtonTable(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInBottomPanelByDefaultClient();
	
EndProcedure

// Procedure - StartChoice event handler in Shortcut column of the form LowerBarButtons tabular section.
//
&AtClient
Procedure LowerBarButtonsShortcutStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.LowerBarButtons.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.ShortcutPreviousValue = CurrentData.Shortcut;
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure("CurrentData, TSName", CurrentData, "LowerBarButtons");
	NotifyDescription = New NotifyDescription("ShortcutSelectionStartEnd", ThisObject, AdditionalParameters);
	OpenForm("Catalog.SettingsCWP.Form.FormShortcutSelection", 
		New Structure("Address, Workplace", AddressInTemporaryStorage(), Object.Workplace), 
		ThisObject, 
		UUID,
		,
		,
		NotifyDescription, 
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

// Procedure - Clearing event handler in Shortcut column of the form LowerBarButtons tabular section.
//
&AtClient
Procedure LowerBarButtonsShortcutClearing(Item, StandardProcessing)
	
	CurrentData = Items.LowerBarButtons.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.Key = String(Key.No);
	CurrentData.Ctrl = False;
	CurrentData.Shift = False;
	CurrentData.Alt = False;
	CurrentData.Shortcut = "";
	
EndProcedure

#EndRegion

#Region FillingFastProducts

// Procedure - FillFromProductsAndServicesGroup command handler of the form.
//
&AtClient
Procedure FillFromProductsAndServicesGroup(Command)
	
	Notification = New NotifyDescription("FillInFromProductsAndServicesGroupEnd", ThisForm);
	OpenForm("Catalog.ProductsAndServices.FolderChoiceForm",,,,,,Notification);
	
EndProcedure

// The procedure processes the selection of ProductsAndServices group and fill in QuickSale tabular section by this group items.
//
&AtClient
Procedure FillInFromProductsAndServicesGroupEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("CatalogRef.ProductsAndServices") Then
		
		FillByProductsAndServicesAtServer(Result);
		
	EndIf;
	
EndProcedure

// Procedure fills in QuickSale tabular section by the items of ProductsAndServices group.
//
&AtServer
Procedure FillByProductsAndServicesAtServer(ProductsAndServicesGroup)

	If Object.Workplace.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = "Select working";
		Message.Message();
		Return;
	EndIf;
	
	Workplace = Object.Workplace;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuickSale.ProductsAndServices
		|INTO QuickSale
		|FROM
		|	&QuickSale AS QuickSale
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductsAndServicesCatalog.Ref
		|FROM
		|	Catalog.ProductsAndServices AS ProductsAndServicesCatalog
		|		LEFT JOIN QuickSale AS QuickSale
		|		ON (QuickSale.ProductsAndServices = ProductsAndServicesCatalog.Ref)
		|WHERE
		|	QuickSale.ProductsAndServices IS NULL 
		|	AND Not ProductsAndServicesCatalog.IsFolder
		|	AND Not ProductsAndServicesCatalog.DeletionMark
		|	AND ProductsAndServicesCatalog.Ref IN HIERARCHY(&ProductsAndServicesGroup)
		|
		|ORDER BY
		|	ProductsAndServicesCatalog.Description";
	
	Query.SetParameter("ProductsAndServicesGroup", ProductsAndServicesGroup);
	Query.SetParameter("QuickSale", Object.QuickSale.Unload(, "ProductsAndServices"));
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = Object.QuickSale.Add();
		NewRow.ProductsAndServices = Selection.Ref;
	EndDo;
	
	Message = New UserMessage;
	Message.Text = "Filling in is completed!";
	Message.Message();
	
EndProcedure

// Procedure - CopyAllToAnotherWorkplace command handler of forms.
//
&AtClient
Procedure CopyAllToAnotherWorkplace(Command)
	
	Notification = New NotifyDescription("CopyAllToAnotherWorkplaceEnd", ThisForm);
	OpenForm("Catalog.SettingsCWP.ChoiceForm",,,,,,Notification);
	
EndProcedure

// The procedure processes the selection of SettingsCWP catalog item and fill in QuickSale tabular section for the selected item.
//
&AtClient
Procedure CopyAllToAnotherWorkplaceEnd(Result, Parameters) Export
	
	If ValueIsFilled(Result) Then
		CopySettingsToSourceFromReceiver(Result, True);
	EndIf;
	
EndProcedure

// Procedure - CopyAllProductsFromAnotherWorkplace command handler of forms.
//
&AtClient
Procedure CopyAllProductsFromAnotherWorkplace(Command)
	
	Notification = New NotifyDescription("CopyAllProductsFromAnotherWorkplaceEnd", ThisForm);
	OpenForm("Catalog.SettingsCWP.ChoiceForm",,,,,,Notification);
	
EndProcedure

// The procedure processes the selection of SettingsCWP catalog item and fill in QuickSale tabular section for the current item.
//
&AtClient
Procedure CopyAllProductsFromAnotherWorkplaceEnd(Result, Parameters) Export
	
	If ValueIsFilled(Result) Then
		CopySettingsToSourceFromReceiver(Result);
	EndIf;
	
EndProcedure

// The procedure copies the QuickSale tabular section of a single item of SettingsCWP catalog to another one. 
// Current item can function as a receiver and source.
//
&AtServer
Procedure CopySettingsToSourceFromReceiver(Settings, TheReceiver = False)
	
	If TheReceiver Then
		SourceSettings = Object;
		ReceiverSettings = Settings.GetObject();
	Else
		SourceSettings = Settings;
		ReceiverSettings = Object;
	EndIf;
	
	If SourceSettings.Ref = ReceiverSettings.Ref Then
		Message = New UserMessage;
		Message.Text = "Current settings are selected! Copying is not completed!";
		Message.Message();
		Return;
	EndIf;
	
	For Each RowSource IN SourceSettings.QuickSale Do
		FromSearch = New Structure("ProductsAndServices, Characteristic", RowSource.ProductsAndServices, RowSource.Characteristic);
		FoundStrings = ReceiverSettings.QuickSale.FindRows(FromSearch);
		If FoundStrings.Count() = 0 Then
			RowReceiver = ReceiverSettings.QuickSale.Add();
			FillPropertyValues(RowReceiver, RowSource);
		Else
			For Each RowReceiver IN FoundStrings Do
				FillPropertyValues(RowReceiver, RowSource);
			EndDo;
		EndIf;
	EndDo;
	
	If TheReceiver Then
		Try
			ReceiverSettings.Write();
		Except
			Message(ErrorDescription());
		EndTry;
	EndIf;
	
	Message = New UserMessage;
	Message.Text = "Filling in is completed!";
	Message.Message();
	
EndProcedure

#EndRegion















