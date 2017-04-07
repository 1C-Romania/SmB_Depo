
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.HeaderText) Then
		Title = Parameters.HeaderText;
	EndIf;
	
	Items.ExplanationText.Title = Parameters.ExplanationText;
	Items.ExplanationText.Visible = Not IsBlankString(Parameters.ExplanationText);
	
	DataType = Parameters.DataType;
	CreatedAttributes = New Array;
	
	If DataType = "string" Then
		InputData = "";
		
	ElsIf DataType = "dateTime" Then
		InputData = '00010101';
		
	ElsIf DataType = "date" Then
		InputData = '00010101';
		Items.InputData.EditFormat = "DLF=D";
		
	ElsIf DataType = "time" Then
		InputData = '00010101';
		Items.InputData.EditFormat = "DLF=T";
		Items.InputData.ChoiceButton = False;
		
	ElsIf DataType = "number" Then
		InputData = 0;
		Items.InputData.EditFormat = "NFD="
			+ ?(IsBlankString(Parameters.FigurePrecision), "0", Parameters.FigurePrecision);
		
	Else
		Raise NStr("en='Unknown type of input data.';ru='Неизвестный тип вводимых данных.'");
		
	EndIf;
	
	UnsetWindowSizeAndLocation();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	Close(XMLValueString(InputData));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UnsetWindowSizeAndLocation()
	
	If AccessRight("SaveUserData", Metadata) Then
		UserName = InfobaseUsers.CurrentUser().Name;
		SystemSettingsStorage.Delete("DataProcessor.OnlineSupportBasicFunctions.Form.DataEntry",
			"",
			UserName);
	EndIf;
	
	WindowOptionsKey = String(New UUID);
	
EndProcedure

&AtServerNoContext
Function XMLValueString(Val Value) Export
	Return XMLString(Value);
EndFunction

#EndRegion
