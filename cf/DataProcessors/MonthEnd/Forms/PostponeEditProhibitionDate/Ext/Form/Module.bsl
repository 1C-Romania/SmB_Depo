
&AtClient
Procedure Yes(Command)
	
	If DontAskAgain Then
		SetDoNotAskAnyMore(True);
	EndIf;
	
	Close(DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure No(Command)
	
	If DontAskAgain Then
		SetDoNotAskAnyMore(False);
	EndIf;
	
	Close();
	
EndProcedure

&AtServerNoContext
Procedure SetDoNotAskAnyMore(YesNoSettingVariant)
	
	If YesNoSettingVariant Then
		Constants.PostponeEditProhibitionDate.Set(Enums.YesNo.Yes);
	Else
		Constants.PostponeEditProhibitionDate.Set(Enums.YesNo.No);
	EndIf;
	
EndProcedure














