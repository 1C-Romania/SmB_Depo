#Region EventsHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	ChoiceData = New ValueList;
	ChoiceData.LoadValues(EquipmentManagerServerCallOverridable.GetAvailableEquipmentTypes());
	StandardProcessing = False;
	
EndProcedure

#EndRegion