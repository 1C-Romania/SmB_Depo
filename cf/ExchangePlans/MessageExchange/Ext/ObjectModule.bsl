#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsNew() Then
		
		If DeletionMark <> CommonUse.ObjectAttributeValue(Ref, "DeletionMark") Then
			
			SetPrivilegedMode(True);
			
			CommonUse.SetDeletionMarkForSubordinatedObjects(Ref, DeletionMark);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf