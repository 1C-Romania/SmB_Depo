
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
	
	User = Users.CurrentUser();
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();
	
	RecordSet.Filter.User.Use = True;
	RecordSet.Filter.User.Value = User;
	RecordSet.Filter.Settings.Use = True;
	RecordSet.Filter.Settings.Value = ChartsOfCharacteristicTypes.UserSettings.OffsetAdvancesDebtsAutomatically;
	
	Record = RecordSet.Add();
	
	Record.User = User;
	Record.Settings = ChartsOfCharacteristicTypes.UserSettings.OffsetAdvancesDebtsAutomatically;
	If YesNoSettingVariant Then
		Record.Value = ChartsOfCharacteristicTypes.UserSettings.OffsetAdvancesDebtsAutomatically.ValueType.AdjustValue(Enums.YesNo.Yes);
	Else
		Record.Value = ChartsOfCharacteristicTypes.UserSettings.OffsetAdvancesDebtsAutomatically.ValueType.AdjustValue(Enums.YesNo.No);
	EndIf;
	
	RecordSet.Write();
	
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisForm.Title = Parameters.HeaderText;
	Items.TextDecoration.Title = Parameters.HeaderText;
	
EndProcedure














