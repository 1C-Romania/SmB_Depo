#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert("CurrentValue", Constants.UseSeparationByDataAreas.Get());
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// The following constants are mutually exclusive, they are used in the individual functional options.
	//
	// Constant.IsOfflineWorkplace                ->
	// FO.WorkInOfflineMode Constant.DontUseSeparationByDataAreas
	// -> FO.WorkInLocalMode Constant.UseSeparationByDataAreas -> FO.SaaS
	//
	// Constants names are saved for the backward compatibility.
	
	If Value Then
		
		Constants.DontUseSeparationByDataAreas.Set(False);
		Constants.ThisIsOfflineWorkplace.Set(False);
		
	ElsIf Constants.ThisIsOfflineWorkplace.Get() Then
		
		Constants.DontUseSeparationByDataAreas.Set(False);
		
	Else
		
		Constants.DontUseSeparationByDataAreas.Set(True);
		
	EndIf;
	
	If AdditionalProperties.CurrentValue <> Value Then
		RefreshReusableValues();
		If Value Then
			EventHandlers = CommonUse.ServiceEventProcessor(
				"StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas");
			
			For Each Handler IN EventHandlers Do
				Handler.Module.OnEnableSeparationByDataAreas();
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf