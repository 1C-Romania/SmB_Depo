#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Prevents from changing the change prohibition dates sections
// which should be changed in the designer mode only.
//
Procedure BeforeWrite(Cancel)
	
	If Predefined AND DataExchange.Load Then
		FillPropertyValues(ThisObject, CommonUse.ObjectAttributesValues(Ref, "ValueType, Description"));
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Raise(NStr("en = 'You can change the
	                 |sections of the change prohibition dates in the Designer only.
	                 |
	                 |Deleting is allowed.'"));
	
EndProcedure

#EndRegion

#EndIf