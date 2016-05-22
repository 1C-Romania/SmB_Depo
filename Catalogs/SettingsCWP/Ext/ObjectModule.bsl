#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// The procedure fills in tabular section of LowerBarButtons based on LowerBarButtonsStandardFunctions layout data
//
Procedure FillInButtonsTableFromLayout() Export

	Template = Catalogs.SettingsCWP.GetTemplate("LowerBarButtonsStandardFunctions");
	
	LineNumbers = Template.TableHeight;
	
	For LayoutLineNumber = 2 To LineNumbers Do
		
		TableRow = New Structure;
		
		TableRow.Insert("ButtonPresentation", Template.Area(LayoutLineNumber,1,LayoutLineNumber,1).Text);
		TableRow.Insert("CommandName", Template.Area(LayoutLineNumber,2,LayoutLineNumber,2).Text);
		TableRow.Insert("ButtonName", Template.Area(LayoutLineNumber,3,LayoutLineNumber,3).Text);
		TableRow.Insert("ButtonTitle", Template.Area(LayoutLineNumber,4,LayoutLineNumber,4).Text);
		TableRow.Insert("Key", Template.Area(LayoutLineNumber,6,LayoutLineNumber,6).Text);
		TableRow.Insert("Alt", Boolean(Template.Area(LayoutLineNumber,7,LayoutLineNumber,7).Text));
		TableRow.Insert("Ctrl", Boolean(Template.Area(LayoutLineNumber,8,LayoutLineNumber,8).Text));
		TableRow.Insert("Shift", Boolean(Template.Area(LayoutLineNumber,9,LayoutLineNumber,9).Text));
		TableRow.Insert("Default", Boolean(Template.Area(LayoutLineNumber,10,LayoutLineNumber,10).Text));
		
		CurrentData = LowerBarButtons.Add();
		FillPropertyValues(CurrentData, TableRow);
		
		CurrentData.Shortcut = ShortcutPresentationByElements(CurrentData.Key, CurrentData.Alt, CurrentData.Ctrl, CurrentData.Shift, True);
		
	EndDo;
	
EndProcedure // FillInButtonsTableFromLayout()

// Function returns the key combination presentation by separate elements of this combination
//
// Parameters:
//  Key - Alt
//  key - Boolean - Alt Ctrl
//  key is pressed - Boolean - Alt Shift
//  key is pressed - Boolean - Alt WithoutBrackets
//  key is pressed - Boolean - If true, then the return value is in round brackets
//
// Return
// Value String - Key presentation
//
Function ShortcutPresentationByElements(Key, Alt, Ctrl, Shift, WithoutParentheses = False) Export
	
	If Key = "" Then
		Return "";
	EndIf;
	
	ShortcutPresentation = ?(WithoutParentheses, "", "(");
	If Ctrl Then
		ShortcutPresentation = ShortcutPresentation + "Ctrl+"
	EndIf;
	If Alt Then
		ShortcutPresentation = ShortcutPresentation + "Alt+"
	EndIf;
	If Shift Then
		ShortcutPresentation = ShortcutPresentation + "Shift+"
	EndIf;
	ShortcutPresentation = ShortcutPresentation + KeyPresentation(Key) + ?(WithoutParentheses, "", ")");
	
	Return ShortcutPresentation;
	
EndFunction

// The function returns
// the Parameters key presentation:
// ValueKey						- Key
//
// Return
// Value String - Key presentation
//
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

#EndRegion

#EndIf