
#Region FormEventsHandlers

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterSendingMethod = Settings.Get("FilterSendingMethod");
	FilterState = Settings.Get("FilterState");
	FilterResponsible = Settings.Get("FilterResponsible");
	
	SmallBusinessClientServer.SetListFilterItem(List, "SendingMethod", FilterSendingMethod, ValueIsFilled(FilterSendingMethod));
	SmallBusinessClientServer.SetListFilterItem(List, "Status", FilterState, ValueIsFilled(FilterState));
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure FilterSendingMethodOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "SendingMethod", FilterSendingMethod, ValueIsFilled(FilterSendingMethod));
	
EndProcedure

&AtClient
Procedure FilterStateOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "State", FilterState, ValueIsFilled(FilterState));
	
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

#EndRegion














