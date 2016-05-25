
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Title allocation.
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
		HeaderWidth = 1.3 * StrLen(Title);
		If HeaderWidth > 40 AND HeaderWidth < 80 Then
			Width = HeaderWidth;
		EndIf;
	EndIf;
	
	// Text allocation.
	If StrLineCount(Parameters.MessageText) < 15 Then
		// You can show all rows as a label.
		Items.MessageText.Title = Parameters.MessageText;
		Items.MultipageMessageText.Visible = False;
	Else
		// Multiline mode.
		Items.MessageText.Visible = False;
		MessageText = Parameters.MessageText;
	EndIf;
	
	// Reset size and position of window of this form.
	WindowOptionsKey = New UUID;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	Close();
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
