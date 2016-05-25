
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	RelativeSize = Parameters.RelativeSize;
	MinimalEffect = Parameters.MinimalEffect;
	Items.MinimalEffect.Visible = Parameters.RebuildingMode;
	Title = ?(Parameters.RebuildingMode,
	              NStr("en='Rebuilding parameters'"),
	              NStr("en='Optimal aggregate calculation parameter'"));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure("RelativeSize, MinimalEffect");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
	
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
