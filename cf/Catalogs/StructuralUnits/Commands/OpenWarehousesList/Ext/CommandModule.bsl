
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterArray	= New Array;
	FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Warehouse"));
	FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Retail"));
	FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.RetailAccrualAccounting"));
	
	FilterStructure	= New Structure("StructuralUnitType", FilterArray);
	
	FormParameters	= New Structure;
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("PurposeUseKey", "Warehouses");
	
	OpenForm("Catalog.StructuralUnits.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure
