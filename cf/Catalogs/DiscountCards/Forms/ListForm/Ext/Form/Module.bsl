
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		If ValueIsFilled(Parameters.Filter.Owner) Then // It is not necessary to show the "Discount card kind" column.
			CurCardKind = Parameters.Filter.Owner;
			
			Items.Owner.Visible = False;
			Items.CardCodeMagnetic.Visible = CurCardKind.CardType = Enums.CardsTypes.Magnetic
	                                               Or CurCardKind.CardType = Enums.CardsTypes.Mixed;
			Items.CardCodeBarcode.Visible = CurCardKind.CardType = Enums.CardsTypes.Barcode
	                                      Or CurCardKind.CardType = Enums.CardsTypes.Mixed;

		Else // Show all columns.
			Items.Owner.Visible = True;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
