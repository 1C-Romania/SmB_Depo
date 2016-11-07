
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Properties = ChangeProhibitionDatesServiceReUse.SectionsProperties();
	
	// Report version setting.
	If Parameters.BySectionsObjects = True Then
		
		If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ImportingProhibitionDatesBySectionsObjectsForUsers");
			
		ElsIf Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ImportingProhibitionDatesBySectionsForUsers");
		Else
			SetCurrentVariant("ImportingProhibitionDatesByObjectsForUsers");
		EndIf;
	Else
		If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ImportingProhibitionDatesByUsers");
			
		ElsIf Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ImportingProhibitionDatesByUsersWithoutObjects");
		Else
			SetCurrentVariant("ImportingProhibitionDatesByUsersWithoutSections");
		EndIf;
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
