
#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DirectionOnChange(Item)
	
	CreateCondition();
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	CreateCondition();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure("Direction, State");
	ChoiceResult.Direction = Direction;
	ChoiceResult.State = State;
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CreateCondition()
	
	If Direction > 0 Then
		If Upper(State) = "Good" Then
			Limit = 0.93;
		ElsIf Upper(State) = "Satisfactorily" Then
			Limit = 0.84;
		ElsIf Upper(State) = "Bad" Then
			Limit = 0.69;
		EndIf;
		Condition = "apdex > " + Limit;
	ElsIf Direction < 0 Then
		If Upper(State) = "Good" Then
			Limit = 0.85;
		ElsIf Upper(State) = "Satisfactorily" Then
			Limit = 0.7;
		ElsIf Upper(State) = "Bad" Then
			Limit = 0.5;
		EndIf;
		Condition = "apdex < " + Limit;
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
