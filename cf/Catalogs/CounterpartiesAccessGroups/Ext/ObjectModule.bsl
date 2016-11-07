#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)

	If DataExchange.Load Then
		Return;
	EndIf;

	// Filling the attribute for RLS.
	If Not IsNew() Then
		AccessGroup = Ref;
	ElsIf ValueIsFilled(GetNewObjectRef()) Then
		AccessGroup = GetNewObjectRef();
	Else
		AccessGroup = Catalogs.CounterpartiesAccessGroups.GetRef();
		SetNewObjectRef(AccessGroup);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf