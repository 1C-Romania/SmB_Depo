#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel, Replacing)
	
	// The DataExchange.Load property valueis not checked for the reason that the restrictions imposed by this code should not be bypassed by setting this property to True (on the side of the code which attempts to write to this register).
	//
	// This register should not be involved into any exchanges or data export / import operations when data distribution by areas is enabled.
	
	If Not CommonUseReUse.SessionWithoutSeparator() Then
		
		Raise NStr("en = 'Access violation!'");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf