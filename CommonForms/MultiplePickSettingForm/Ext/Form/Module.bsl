////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// The procedure writes the filter settings to the user settings
//
Procedure WriteReportSettings()

	SmallBusinessServer.SetUserSetting(ShowBalance, 		"ShowBalance");
	SmallBusinessServer.SetUserSetting(ShowReserve, 		"ShowReserve");
	SmallBusinessServer.SetUserSetting(ShowAvailableBalance, "ShowAvailableBalance");
	SmallBusinessServer.SetUserSetting(ShowPrices, 		"ShowPrices");
	SmallBusinessServer.SetUserSetting(OutputBalancesMethod,	"OutputBalancesMethod");
	SmallBusinessServer.SetUserSetting(KeepCurrentHierarchy, "KeepCurrentHierarchy");
	
EndProcedure // WriteReportSettings()

&AtClient
// The procedure manages the availability of form items.
// 
// To minimize server calls the availability is controlled by the form pages
//
Procedure SetSwitchesEnabled(AvailabilityFlag)
	
	Items.GroupBalancesOutputMethod.CurrentPage = 
		?(AvailabilityFlag, 
			Items.GroupBalancesOutputMethod.ChildItems.PageSwitchAvailable, 
			Items.GroupBalancesOutputMethod.ChildItems.PageSwitchIsNotAvailable);
	
EndProcedure // SetSwitchesEnabled()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User 			= Users.CurrentUser();
	OutputBalancesMethod	= SmallBusinessReUse.GetValueByDefaultUser(User, "OutputBalancesMethod");
	OutputBalancesMethod	= ?(ValueIsFilled(OutputBalancesMethod), OutputBalancesMethod, Enums.BalancesOutputMethodInSelection.InTable);
	
	SettingsStructure = New Structure("ShowBalance, ShowPrices, OutputBalancesMethod, KeepCurrentHierarchy",
				SmallBusinessReUse.GetValueByDefaultUser(User, "ShowBalance"),
				SmallBusinessReUse.GetValueByDefaultUser(User, "ShowPrices"),
				OutputBalancesMethod,
				SmallBusinessReUse.GetValueByDefaultUser(User, "KeepCurrentHierarchy"));
				
	//If redundancy is disabled, then there is no use to work with the redundancy switches and free balances
	InventoryReservationConstantValue = GetFunctionalOption("InventoryReservation"); 
	
	SettingsStructure.Insert("ShowReserve", 
		?(InventoryReservationConstantValue,
			SmallBusinessReUse.GetValueByDefaultUser(User, "ShowReserve"),
			False)
		);
		
	SettingsStructure.Insert("ShowAvailableBalance", 
		?(InventoryReservationConstantValue,
			SmallBusinessReUse.GetValueByDefaultUser(User, "ShowAvailableBalance"),
			False)
		);
		
	Items.ShowReserve.Enabled			= InventoryReservationConstantValue;
	Items.ShowAvailableBalance.Enabled	= InventoryReservationConstantValue;
	
	//Fill values
	FillPropertyValues(ThisForm, SettingsStructure);
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - form event handler OnOpen
//
Procedure OnOpen(Cancel)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure // OnOpen()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

&AtClient
// Procedure - command handler "OK"
//
Procedure OK(Command)
	
	WriteReportSettings();
	Close(New Structure("ShowBalance, ShowReserve, ShowAvailableBalance, ShowPrices, OutputBalancesMethod, KeepCurrentHierarchy", 
			ShowBalance, 
			ShowReserve, 
			ShowAvailableBalance, 
			ShowPrices, 
			OutputBalancesMethod, 
			KeepCurrentHierarchy));
	
EndProcedure // Ok()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - OnChange event handler of the ShowBalance attribute
//
Procedure ShowBalancesOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure // ShowBalancesOnChange()

&AtClient
// Procedure - OnChange event handler of the ShowReserve attribute
//
Procedure ShowReserveOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure // ShowReserveOnChange()

&AtClient
// Procedure - OnChange event handler of the ShowAvailableBalance attribute
//
Procedure ShowAvailableBalanceOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure // ShowAvailableBalanceOnChange()

&AtClient
//  Procedure - OnChange event handler of the ShowPrices attribute
//
Procedure ShowPricesOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure // ShowPricesOnChange()
// 
