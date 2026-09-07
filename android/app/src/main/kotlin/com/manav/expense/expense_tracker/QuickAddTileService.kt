package com.manav.expense.expense_tracker

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class QuickAddTileService : TileService() {
    
    override fun onClick() {
        super.onClick()
        
        // Open the Quick Add Activity
        val intent = Intent(this, QuickAddActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivityAndCollapse(intent)
    }

    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile
        if (tile != null) {
            tile.state = Tile.STATE_ACTIVE
            tile.updateTile()
        }
    }
}
