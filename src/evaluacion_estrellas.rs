/*
#![no_std]

#[allow(unused_imports)]
use multiversx_sc::imports::*;

/// An empty contract. To be used as a template when starting a new contract from scratch.
#[multiversx_sc::contract]
pub trait EvaluacionEstrellas {
    #[init]
    fn init(&self) {}

    #[upgrade]
    fn upgrade(&self) {}
}

*/
#![no_std]

multiversx_sc::imports!();
multiversx_sc::derive_imports!();

/// Contrato evaluable con votos de 1 a 5 estrellas hasta una fecha límite.
#[multiversx_sc::contract]
pub trait EvaluacionPorEstrellas {
    #[init]
    fn init(&self, fecha_limite: u64) {
        self.fecha_limite().set(fecha_limite);
    }

    /// Vota con una puntuación entre 1 y 5. Solo una vez por address, antes de la fecha límite.
    #[endpoint]
    fn votar(&self, puntuacion: u8) {
        let ahora = self.blockchain().get_block_timestamp();
        let votante = self.blockchain().get_caller();

        require!(ahora <= self.fecha_limite().get(), "Periodo de votación finalizado");
        require!(puntuacion >= 1 && puntuacion <= 5, "Puntuación inválida");
        require!(!self.votantes(&votante).is_empty(), "Ya has votado");

        self.votantes(&votante).set(&ManagedBuffer::from(&[1u8])); // Marca como votado
        self.suma().update(|s| *s += puntuacion as u64);
        self.total().update(|t| *t += 1);
    }

    /// Devuelve la media actual de puntuaciones (entero redondeado hacia abajo)
    #[view(getMedia)]
    fn get_media(&self) -> u8 {
        let total = self.total().get();
        if total == 0 {
            return 0;
        }
        let suma = self.suma().get();
        (suma / total) as u8
    }

    /// Devuelve el total de votos recibidos
    #[view(getTotal)]
    fn get_total(&self) -> u64 {
        self.total().get()
    }

    /// Devuelve la fecha límite de votación (timestamp)
    #[view(getDeadline)]
    fn get_fecha_limite(&self) -> u64 {
        self.fecha_limite().get()
    }

    #[storage_mapper("suma")]
    fn suma(&self) -> SingleValueMapper<u64>;

    #[storage_mapper("total")]
    fn total(&self) -> SingleValueMapper<u64>;

    #[storage_mapper("fecha_limite")]
    fn fecha_limite(&self) -> SingleValueMapper<u64>;

    #[storage_mapper("votantes")]
    fn votantes(&self, address: &ManagedAddress) -> SingleValueMapper<ManagedBuffer>;
}