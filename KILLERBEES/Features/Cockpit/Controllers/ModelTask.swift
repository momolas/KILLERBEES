//
//  ModelTask.swift
//  KILLERBEES
//
//  Created by Jules
//

import Foundation

/// Type de tâche du modèle d'inférence de vision par ordinateur YOLO.
public enum ModelTask: Sendable {
    case detect
    case segment
    case obb
}
