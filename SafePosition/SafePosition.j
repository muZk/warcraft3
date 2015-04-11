library SafePosition requires WorldBounds /* v0.0.0
************************************************************************************
*
*	struct SafePosition extends array
*
*		Methods
*		-------------------------
*
*			public static boolean isSafe(x, y)
*				Determines if the position (x,y) is a safe position
*
************************************************************************************/

	struct SafePosition extends array
		public static method isSafe takes real x, real y returns boolean
			return not(x > WorldBounds.maxX or x < WorldBounds.minX or y > WorldBounds.maxY or y < WorldBounds.minY)
		endmethod
	endstruct

endlibrary