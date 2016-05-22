
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	KeyArray = New Array;
	
	KeyArray.Add(Key.A);
	KeyArray.Add(Key.B);
	KeyArray.Add(Key.C);
	KeyArray.Add(Key.D);
	KeyArray.Add(Key.E);
	KeyArray.Add(Key.F);
	KeyArray.Add(Key.G);
	KeyArray.Add(Key.H);
	KeyArray.Add(Key.I);
	KeyArray.Add(Key.J);
	KeyArray.Add(Key.K);
	KeyArray.Add(Key.L);
	KeyArray.Add(Key.M);
	KeyArray.Add(Key.N);
	KeyArray.Add(Key.O);
	KeyArray.Add(Key.P);
	KeyArray.Add(Key.Q);
	KeyArray.Add(Key.R);
	KeyArray.Add(Key.S);
	KeyArray.Add(Key.T);
	KeyArray.Add(Key.U);
	KeyArray.Add(Key.V);
	KeyArray.Add(Key.W);
	KeyArray.Add(Key.X);
	KeyArray.Add(Key.Y);
	KeyArray.Add(Key.Z);
	
	KeyArray.Add(Key.F1);
	KeyArray.Add(Key.F2);
	KeyArray.Add(Key.F3);
	KeyArray.Add(Key.F4);
	KeyArray.Add(Key.F5);
	KeyArray.Add(Key.F6);
	KeyArray.Add(Key.F7);
	KeyArray.Add(Key.F8);
	KeyArray.Add(Key.F9);
	KeyArray.Add(Key.F10);
	KeyArray.Add(Key.F11);
	KeyArray.Add(Key.F12);
	
	KeyArray.Add(Key._1);
	KeyArray.Add(Key._2);
	KeyArray.Add(Key._3);
	KeyArray.Add(Key._4);
	KeyArray.Add(Key._5);
	KeyArray.Add(Key._6);
	KeyArray.Add(Key._7);
	KeyArray.Add(Key._8);
	KeyArray.Add(Key._9);
	
	KeyArray.Add(Key.Num0);
	KeyArray.Add(Key.Num1);
	KeyArray.Add(Key.Num2);
	KeyArray.Add(Key.Num3);
	KeyArray.Add(Key.Num4);
	KeyArray.Add(Key.Num5);
	KeyArray.Add(Key.Num6);
	KeyArray.Add(Key.Num7);
	KeyArray.Add(Key.Num8);
	KeyArray.Add(Key.Num9);
	KeyArray.Add(Key.NumAdd);
	KeyArray.Add(Key.NumDecimal);
	KeyArray.Add(Key.NumDivide);
	KeyArray.Add(Key.NumMultiply);
	KeyArray.Add(Key.NumSubtract);
	
	KeyArray.Add(Key.Space);
	KeyArray.Add(Key.BackSpace);
	KeyArray.Add(Key.Break);
	
	Data = GetFromTempStorage(Parameters.Address);
	
	Workplace = Parameters.Workplace;
	
	For Each ItemKey IN KeyArray Do
		
		NewRow = ShortcutsTable.Add();
		NewRow.KeyName = String(ItemKey);
		
		ShortcutPresentation(NewRow, Data, "Key",        New Shortcut(ItemKey, False,   False,   False));
		
		ShortcutPresentation(NewRow, Data, "Ctrl",           New Shortcut(ItemKey, False,   True, False));
		ShortcutPresentation(NewRow, Data, "Alt",            New Shortcut(ItemKey, True, False,   False));
		ShortcutPresentation(NewRow, Data, "Shift",          New Shortcut(ItemKey, False,   False,   True));
		
		ShortcutPresentation(NewRow, Data, "Alt_Shift",      New Shortcut(ItemKey, True, False,   True));
		ShortcutPresentation(NewRow, Data, "Ctrl_Shift",     New Shortcut(ItemKey, False,   True, True));
		ShortcutPresentation(NewRow, Data, "Ctrl_Alt",       New Shortcut(ItemKey, True, True, False));
		ShortcutPresentation(NewRow, Data, "Ctrl_Alt_Shift", New Shortcut(ItemKey, True, True, True));
		
	EndDo;

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// Procedure - OnActivateRow event handler in ShortcutsTable value table.
//
&AtClient
Procedure ShortcutsTableOnActivateRow(Item)
	
	If Item.CurrentItem = Undefined Then
		Return;
	EndIf;
	
	Shortcut = SelectedShortcut(Item.CurrentData, Item.CurrentItem);
	Presentation = Presentation(Shortcut);
	
EndProcedure

// Procedure - OnActivateField event handler in ShortcutsTable values table.
//
&AtClient
Procedure ShortcutsTableOnActivateField(Item)
	
	Shortcut = SelectedShortcut(Item.CurrentData, Item.CurrentItem);
	Presentation = Presentation(Shortcut);
	
EndProcedure

// Procedure - Selection event handler in ShortcutsTable values table.
//
&AtClient
Procedure ShortcutsTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = ShortcutsTable.FindByID(SelectedRow);
	Close(SelectedShortcut(CurrentData, Field));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - Select forms command handler.
//
&AtClient
Procedure Select(Command)
	
	Close(Shortcut);
	
EndProcedure

&AtClient
Procedure Attachable_ExecuteOverriddenCommand(Command)
	
	//ExecuteOverriddenCommand(ThisForm, Command);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Other

// The function returns the selected (highlighted) combination of keys.
//
&AtClient
Function SelectedShortcut(CurrentData, Field)
	
	Array = New Array;
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableKey,        False,   False,   False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableAlt,            True, False,   False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl,           False,   True, False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableShift,          False,   False,   True));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableAlt_Shift,      True, False,   True));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_Alt,       True, True, False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_Shift,     False,   True, True));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_Alt_Shift, True, True, True));
	
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableKey_,        False,   False,   False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableAlt_,            True, False,   False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_,           False,   True, False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableShift_,          False,   False,   True));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableAlt_Shift_,      True, False,   True));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_Alt_,       True, True, False));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_Shift_,     False,   True, True));
	Array.Add(New Structure("Item,Alt,Ctrl,Shift", Items.ShortcutsTableCtrl_Alt_Shift_, True, True, True));
	
	For Each ArrayElement IN Array Do
		
		If ArrayElement.Item = Field Then
			
			KeyName = CurrentData.KeyName;
			Return New Structure("Key,Alt,Ctrl,Shift", KeyName, ArrayElement.Alt, ArrayElement.Ctrl, ArrayElement.Shift);
			
		EndIf;
		
	EndDo;
	
EndFunction

// The function returns the key combination presentation.
//
&AtServerNoContext
Function Presentation(Shortcut)
	
	Return ShortcutPresentation2(Shortcut, True);
	
EndFunction

// The function returns the key combination presentation and sets the name+"_", 
// i.e. data of products and services or button using this combination.
// Parameters:
//  Shortcut						           - Combination of keys that require
//  WithoutBrackets presentation	  - The flag indicating that the presentation shall be formed without brackets
//
// Return value
//  String - Key combination presentation
//
&AtServer
Procedure ShortcutPresentation(NewRow, Data, Name, Combination)
	
	NewRow[Name] = ShortcutPresentation2(Combination, True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuickSale.ProductsAndServices,
		|	QuickSale.Characteristic,
		|	QuickSale.Ctrl,
		|	QuickSale.Shift,
		|	QuickSale.Alt,
		|	QuickSale.Shortcut,
		|	QuickSale.Key,
		|	QuickSale.Title,
		|	QuickSale.SortingField,
		|	QuickSale.ProductsAndServices.Description AS ProductsAndServicesDescription,
		|	QuickSale.Characteristic.Description AS CharacteristicDescription
		|FROM
		|	Catalog.SettingsCWP.QuickSale AS QuickSale
		|WHERE
		|	QuickSale.Ctrl = &Ctrl
		|	AND QuickSale.Shift = &Shift
		|	AND QuickSale.Alt = &Alt
		|	AND QuickSale.Key LIKE &Key
		|	AND QuickSale.Ref.Workplace = &Workplace
		|
		|UNION ALL
		|
		|SELECT
		|	NULL,
		|	NULL,
		|	LowerBarButtons.Ctrl,
		|	LowerBarButtons.Shift,
		|	LowerBarButtons.Alt,
		|	LowerBarButtons.Shortcut,
		|	LowerBarButtons.Key,
		|	LowerBarButtons.ButtonTitle,
		|	NULL,
		|	NULL,
		|	NULL
		|FROM
		|	Catalog.SettingsCWP.LowerBarButtons AS LowerBarButtons
		|WHERE
		|	LowerBarButtons.Ctrl = &Ctrl
		|	AND LowerBarButtons.Shift = &Shift
		|	AND LowerBarButtons.Alt = &Alt
		|	AND LowerBarButtons.Key LIKE &Key
		|	AND LowerBarButtons.Ref.Workplace = &Workplace";
	
	Query.SetParameter("Alt", Combination.Alt);
	Query.SetParameter("Ctrl", Combination.Ctrl);
	Query.SetParameter("Shift", Combination.Shift);
	Query.SetParameter("Key", String(Combination.Key));
	Query.SetParameter("Workplace", Workplace);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		If ValueIsFilled(SelectionDetailRecords.Title) Then
			NewRow[Name+"_"] = SelectionDetailRecords.Title;
		Else
			NewRow[Name+"_"] = SelectionDetailRecords.ProductsAndServicesDescription;
		EndIf;
	EndIf;
	
EndProcedure

// The function returns key presentation
// Parameters:
//  ValueKey						- Key
//
// Return value
//  String - Key presentation
//
&AtServerNoContext
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

// The function returns key presentation
// Parameters:
//  Shortcut						- Combination of keys that require the presentation							 
//  WithoutBrackets      - The flag indicating that the presentation shall be formed without brackets
//
// Return value
//  String - Key combination presentation
//
&AtServerNoContext
Function ShortcutPresentation2(Shortcut, WithoutParentheses = False) Export
	
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

#EndRegion

#EndRegion

