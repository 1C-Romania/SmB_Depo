
// Service

&AtServerNoContext
Procedure SaveNewSettingsAndRefreshInterface(ItIsRequiredToRefreshInterface, ModifiedSettings)
	
	For Each SettingItem IN ModifiedSettings Do
		
		CurrentSettingValue = SmallBusinessReUse.GetValueOfSetting(SettingItem.Key);
		If SettingItem.Value <> CurrentSettingValue Then
			
			ItIsRequiredToRefreshInterface = True;
			SmallBusinessServer.SetUserSetting(SettingItem.Value, SettingItem.Key);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Commands

&AtClient
Procedure OK(Command)
	
	ModifiedSettings = New Structure;
	
	If Modified Then
		
		ItIsRequiredToRefreshInterface = False;
		
		ModifiedSettings.Insert("RequestQuantity", RequestQuantity);
		ModifiedSettings.Insert("RequestPrice", RequestPrice);
		
		SaveNewSettingsAndRefreshInterface(ItIsRequiredToRefreshInterface, ModifiedSettings);
		
		If ItIsRequiredToRefreshInterface Then
			
			RefreshInterface();
			
		EndIf;
		
	EndIf;
	
	Close(ModifiedSettings);
	
EndProcedure

// Form

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RequestQuantity = SmallBusinessReUse.GetValueOfSetting("RequestQuantity");
	RequestPrice = SmallBusinessReUse.GetValueOfSetting("RequestPrice");
	
EndProcedure

// Form attributes