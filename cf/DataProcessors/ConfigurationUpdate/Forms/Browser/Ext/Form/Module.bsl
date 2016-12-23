
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;	
	EndIf;
	PageAddress = Parameters.PageAddress;
	HTMLText = PageAddress;
	Items.AddressString.Visible = Parameters.ShowAddressString;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToPage(Command)
	OpenPageAtAddress();
EndProcedure

&AtClient
Procedure Forward(Command)
   Items.HTMLText.Forward();
EndProcedure

&AtClient
Procedure Back(Command)
   Items.HTMLText.Back();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenPageAtAddress()
	HTMLText = PageAddress;
EndProcedure

#EndRegion














