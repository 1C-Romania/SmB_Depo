
#Region ServiceProceduresAndFunctions

&AtClient
Procedure GenerateDescription()
	
	Object.Description = NStr("en='Series ';ru='серия '") + Object.LicenseCardSeries + NStr("en=' # ';ru=' # '") + Object.LicenseCardNumber + NStr("en=' dated ';ru=' от '") + Format(Object.LicenseCardsDateIssued, "DF=dd.MM.yyyy");
	
	If ValueIsFilled(Object.LicenseOwner) Then
		
		Object.Description = Object.Description + NStr("en='. Owner: ';ru='. Владелец: '") + Object.LicenseOwner;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure LicenseCardSeriesOnChange(Item)
	
	GenerateDescription();
	
EndProcedure

&AtClient
Procedure LicenseCardNumberOnChange(Item)
	
	GenerateDescription();
	
EndProcedure

&AtClient
Procedure LicenseCardsDateIssuedOnChange(Item)
	
	GenerateDescription();
	
EndProcedure

&AtClient
Procedure LicenseOwnerOnChange(Item)
	
	GenerateDescription();
	
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
